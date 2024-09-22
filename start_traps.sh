#!/bin/bash
thisdir=$(dirname -- "$(realpath -- "$0")")
cd "${thisdir}"

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

wait "${pids[@]}"
