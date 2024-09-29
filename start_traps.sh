#!/bin/bash
logger -t port_trap.py "Enable port traps..."
thisdir=$(dirname -- "$(realpath -- "$0")")
cd "${thisdir}"

if [ -d "${thisdir}/ipset"]; then
    for set in "${thisdir}/ipset/*.rules"; do
        ipset restore < "${set}"
    done
fi
if ! ipset list port_trap > /dev/null 2>&1; then
    sudo ipset create port_trap hash:ip
fi
if ! ipset list port_trap_perm > /dev/null 2>&1; then
    sudo ipset create port_trap_perm hash:ip
fi
if ! ipset list port_trap_v6 > /dev/null 2>&1; then
    sudo ipset create port_trap_v6 hash:ip family inet6
fi
if ! ipset list port_trap_v6_perm > /dev/null 2>&1; then
    sudo ipset create port_trap_v6_perm hash:ip family inet6
fi
if ! sudo iptables-save | grep -q -- "-A INPUT -m set --match-set port_trap src -j DROP"; then
    sudo iptables -A INPUT -m set --match-set port_trap src -j DROP
fi
if ! sudo iptables-save | grep -q -- "-A INPUT -m set --match-set port_trap_perm src -j DROP"; then
    sudo iptables -A INPUT -m set --match-set port_trap_perm src -j DROP
fi
if ! sudo ip6tables-save | grep -q -- "-A INPUT -m set --match-set port_trap_v6 src -j DROP"; then
    sudo ip6tables -A INPUT -m set --match-set port_trap_v6 src -j DROP
fi
if ! sudo ip6tables-save | grep -q -- "-A INPUT -m set --match-set port_trap_v6_perm src -j DROP"; then
    sudo ip6tables -A INPUT -m set --match-set port_trap_v6_perm src -j DROP
fi

pids=()
sleep 0.5;
for i in $(cat "${thisdir}/list_of_ports.txt" | grep -vE "^#"); do 
    pport=$(echo "$i" | awk -F '#' '{print $1}') 
    ptimeout=$(echo "$i" | awk -F '#' '{print $2}')
    v6=$(echo "$i" | awk -F '#' '{print $3}') 

    if [[ "${v6}" == "6" ]]; then
        echo "Start trap on IPv6 port: ${pport} Timeout: ${ptimeout}" 
        "${thisdir}/port_trap.py" "${pport}" "${ptimeout}" "6" & 
    else
        echo "Start trap on IPv4 port: ${pport} Timeout: ${ptimeout}"
        "${thisdir}/port_trap.py" "${pport}" "${ptimeout}" & 
    fi

    pids+=($!)
    sleep 0.2
done
logger -t port_trap.py "Port traps enabled."
wait "${pids[@]}"
