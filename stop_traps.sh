#!/bin/bash

thisdir=$(dirname -- "$(realpath -- "$0")")
logger -t port_trap.py "Disable port traps..."
if [ ! -d "${thisdir}/ipset" ]; then
    mkdir "${thisdir}/ipset"
fi
if [ -d "${thisdir}/ipset" ]; then
    for setlist in $(ipset list -n); do
        ipset save "${setlist}" > "${thisdir}/ipset/${setlist}.rules"
    done
fi

#echo "Current processes:";
#ps auxfww | grep -vE "grep|systemctl|journalctl"| grep port_trap.py
for i in $(ps auxfww | grep -vE "grep|systemctl|journalctl"| grep port_trap.py | awk '{print $2}'); do kill -15 $i; echo "Stoped PID: ${i}"; done
logger -t port_trap.py "Port traps disabled."
