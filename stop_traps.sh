#!/bin/bash
echo "Current processes:";
ps auxfww | grep -v grep| grep port_trap.py
for i in $(ps auxfww | grep -v grep| grep port_trap.py | awk '{print $2}'); do kill -15 $i; echo "Stoped PID: ${i}"; done
