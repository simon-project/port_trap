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

    echo "";

    if type apt-get > /dev/null 2>&1; then
        apt-get update > /dev/null 2>&1
        COS="deb"
        INSTCMD="apt-get"
    elif type yum > /dev/null 2>&1; then
        COS="rh"
        INSTCMD="yum"
    elif type pacman > /dev/null 2>&1; then
        COS="arch"
        INSTCMD="pacman"
    else
        COS="nan"
    fi

    if ! type ipset > /dev/null 2>&1; then
        echo "ipset required. Installing..."

        case "$INSTCMD" in
            apt-get)
                sudo ${INSTCMD} install -y ipset
                ;;
            yum)
                sudo ${INSTCMD} install -y ipset
                ;;
            pacman)
                sudo ${INSTCMD} -Sy --noconfirm ipset
                ;;
            *)
                echo "ERROR: Can not detect OS package manager. Please, install ipset manually and run ./install.sh again."
                exit 1
                ;;
        esac
    fi

    if ! type ipset > /dev/null 2>&1; then
        echo "ERROR: ipset is not installed ot not available."
        exit 1
    fi

    if ! ipset list port_trap > /dev/null 2>&1; then
        sudo ipset create port_trap hash:ip
        echo "Success ipset port_trap created."
    fi
    if ! ipset list port_trap_perm > /dev/null 2>&1; then
        sudo ipset create port_trap_perm hash:ip
        echo "Success ipset port_trap_perm created."
    fi
    if ! ipset list port_trap_v6 > /dev/null 2>&1; then
        sudo ipset create port_trap_v6 hash:ip family inet6
        echo "Success ipset port_trap_v6 created."
    fi
    if ! ipset list port_trap_v6_perm > /dev/null 2>&1; then
        sudo ipset create port_trap_v6_perm hash:ip family inet6
        echo "Success ipset port_trap_v6_perm created."
    fi
    if ! sudo iptables-save | grep -q -- "-A INPUT -m set --match-set port_trap src -j DROP"; then
        sudo iptables -A INPUT -m set --match-set port_trap src -j DROP
        echo "Success iptables rule created."
    fi
    if ! sudo iptables-save | grep -q -- "-A INPUT -m set --match-set port_trap_perm src -j DROP"; then
        sudo iptables -A INPUT -m set --match-set port_trap_perm src -j DROP
        echo "Success iptables perm rule created."
    fi
    if ! sudo ip6tables-save | grep -q -- "-A INPUT -m set --match-set port_trap_v6 src -j DROP"; then
        sudo ip6tables -A INPUT -m set --match-set port_trap_v6 src -j DROP
        echo "Success ip6tables rule created."
    fi
    if ! sudo ip6tables-save | grep -q -- "-A INPUT -m set --match-set port_trap_v6_perm src -j DROP"; then
        sudo ip6tables -A INPUT -m set --match-set port_trap_v6_perm src -j DROP
        echo "Success ip6tables perm rule created."
    fi
    if [ -f "/etc/iptables/rules.v4" ]; then
        iptables-save > "/etc/iptables/rules.v4"
        echo "Saved iptables rules to /etc/iptables/rules.v4"
    fi
    if [ -f "/etc/iptables/rules.v6" ]; then
        ip6tables-save > "/etc/iptables/rules.v6"
        echo "Saved ip6tables rules to /etc/iptables/rules.v6"
    fi
    echo "Creating cron job at $CRON_FILE"
    echo 'PATH="${PATH}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' | sudo tee "$CRON_FILE" > /dev/null
    echo "*/3 * * * * root /usr/bin/flock -xn /tmp/port_trap_cron.lock -c '${SCRIPT_DIR}/ban.sh' >/dev/null 2>&1" | sudo tee -a "$CRON_FILE" > /dev/null

    echo "Restarting cron service"
    sudo systemctl restart cron
}

uninstall_unit() {
    if sudo iptables-save | grep -q -- "-A INPUT -m set --match-set port_trap src -j DROP"; then
        sudo iptables -D INPUT -m set --match-set port_trap src -j DROP
        echo "Success deleted iptables rule."
    fi
    if sudo iptables-save | grep -q -- "-A INPUT -m set --match-set port_trap_perm src -j DROP"; then
        sudo iptables -D INPUT -m set --match-set port_trap_perm src -j DROP
        echo "Success deleted iptables perm rule."
    fi
    if sudo ipset list port_trap > /dev/null 2>&1; then
        sudo ipset destroy port_trap
        echo "Success deleted ipset port_trap."
    fi
    if sudo ipset list port_trap_perm > /dev/null 2>&1; then
        sudo ipset destroy port_trap_perm 
        echo "Success deleted ipset port_trap_perm."
    fi
    if sudo ip6tables-save | grep -q -- "-A INPUT -m set --match-set port_trap_v6 src -j DROP"; then
        sudo ip6tables -D INPUT -m set --match-set port_trap_v6 src -j DROP
        echo "Success deleted ip6tables rule."
    fi
    if sudo ip6tables-save | grep -q -- "-A INPUT -m set --match-set port_trap_v6_perm src -j DROP"; then
        sudo ip6tables -D INPUT -m set --match-set port_trap_v6_perm src -j DROP
        echo "Success deleted ip6tables perm rule."
    fi
    if sudo ipset list port_trap_v6 > /dev/null 2>&1; then
        sudo ipset destroy port_trap_v6
        echo "Success deleted ipset port_trap_v6."
    fi
    if sudo ipset list port_trap_v6_perm > /dev/null 2>&1; then
        sudo ipset destroy port_trap_v6_perm
        echo "Success deleted ipset port_trap_v6_perm."
    fi
    if [ -f "/etc/iptables/rules.v4" ]; then
        sed -i 's/-A INPUT -m set --match-set port_trap src -j DROP//g' "/etc/iptables/rules.v4"
        sed -i 's/-A INPUT -m set --match-set port_trap_perm src -j DROP//g' "/etc/iptables/rules.v4"
    fi
    if [ -f "/etc/iptables/rules.v6" ]; then
        sed -i 's/-A INPUT -m set --match-set port_trap_v6 src -j DROP//g' "/etc/iptables/rules.v6"
        sed -i 's/-A INPUT -m set --match-set port_trap_v6_perm src -j DROP//g' "/etc/iptables/rules.v6"
    fi


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
