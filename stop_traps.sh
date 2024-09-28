#!/bin/bash

thisdir=$(dirname -- "$(realpath -- "$0")")
logger -t port_trap.py "Disable port traps..."
ipset-save > "${thisdir}/ipset.conf"
#echo "Current processes:";
#ps auxfww | grep -vE "grep|systemctl|journalctl"| grep port_trap.py
for i in $(ps auxfww | grep -vE "grep|systemctl|journalctl"| grep port_trap.py | awk '{print $2}'); do kill -15 $i; echo "Stoped PID: ${i}"; done
logger -t port_trap.py "Port traps disabled."
