#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UNIT_FILE="/etc/systemd/system/port_trap.service"
CRON_FILE="/etc/cron.d/port_trap_cron"

show_help() {
    echo "Usage: $0 [--uninstall | --help | -h]"
    echo ""
    echo "This script installs or uninstalls a systemd unit file for managing"
    echo "the port_trap service using start_traps.sh and stop_traps.sh."
    echo ""
    echo "Options:"
    echo "  --uninstall   Remove the installed systemd unit file."
    echo "  --help        Display this help message."
    echo "  -h            Display this help message."
}

install_unit() {
    echo "Creating systemd unit file at $UNIT_FILE"

    cat << EOF | sudo tee "$UNIT_FILE" > /dev/null
[Unit]
Description=Port Trap Service
After=network.target

[Service]
Type=simple
ExecStart=${SCRIPT_DIR}/start_traps.sh
ExecStop=${SCRIPT_DIR}/stop_traps.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable port_trap.service
    echo "Unit file created and enabled."

    declare -A files=(
        ["list_of_ports.txt"]="list_of_ports.txt.example"
        ["whitelist.txt"]="whitelist.txt.example"
        ["for_permanent_ban.txt"]="for_permanent_ban.txt.example"
    )

    for file in "${!files[@]}"; do
        if [[ ! -f "$SCRIPT_DIR/$file" ]]; then
            if [[ -f "$SCRIPT_DIR/${files[$file]}" ]]; then
                echo "Copying ${files[$file]} to $file"
                cp "$SCRIPT_DIR/${files[$file]}" "$SCRIPT_DIR/$file"
            else
                echo "Error: $file is missing and ${files[$file]} is also not found."
                exit 1
            fi
        fi
    done

    chmod +x "${SCRIPT_DIR}"/*.sh "${SCRIPT_DIR}"/*.py

    echo "Creating cron job at $CRON_FILE"
    echo 'PATH="${PATH}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' | sudo tee "$CRON_FILE" > /dev/null
    echo "*/3 * * * * root ${SCRIPT_DIR}/ban.sh >/dev/null 2>&1" | sudo tee -a "$CRON_FILE" > /dev/null

    echo "Restarting cron service"
    sudo systemctl restart cron
}

uninstall_unit() {
    if [ -f "$UNIT_FILE" ]; then
        echo "Removing systemd unit file at $UNIT_FILE"
        sudo systemctl disable port_trap.service
        sudo rm "$UNIT_FILE"
        sudo systemctl daemon-reload
        echo "Unit file removed."
    else
        echo "Unit file not found at $UNIT_FILE."
    fi

    if [ -f "$CRON_FILE" ]; then
        echo "Removing cron job at $CRON_FILE"
        sudo rm "$CRON_FILE"
        echo "Cron job removed."
    else
        echo "Cron job not found at $CRON_FILE."
    fi
}

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    show_help
    exit 0
elif [[ "$1" == "--uninstall" ]]; then
    uninstall_unit
    exit 0
else
    install_unit
fi
