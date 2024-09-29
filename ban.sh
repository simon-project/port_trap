#!/bin/bash
PATH="${PATH}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
thisdir=$(dirname -- "$(realpath -- "$0")");

if [ ! -f "${thisdir}/datatrap.db" ]; then
    echo "${thisdir}/datatrap.db not found - please run start_traps.sh first";
    exit 1;
fi

function wlcheck() {
    wl="0";
    for i in $(ip a | grep -E 'inet(6)? ' | awk '{print $2}'| awk -F '/' '{print $1}'); do 
        wlcheck=$(echo ${1} | grep -E "^${i}$" | wc -l)
        if [[ "${wlcheck}" != "0" ]]; then
            wl="1";
        fi
    done
    for i in $(cat "${thisdir}/whitelist.txt" | grep -vE "^#"); do
        wlcheck=$(echo ${1} | grep -E "^${i}$" | wc -l)
        if [[ "${wlcheck}" != "0" ]]; then
            wl="1";
        fi
    done
    echo "${wl}";
}

#temporary ban
if [[ "${1}" != "" && "${2}" != "" ]]; then
    wl=$(wlcheck "${1}");
    if [[ "${wl}" != "1" ]]; then
        if [[ "$(echo ${1} | grep ':' | wc -l)" == "0" ]]; then
            #listed=$(iptables-save | grep "s ${1}/" | grep "trap on port" | wc -l)
            listed=$(ipset test port_trap "${1}" 2>/dev/null && echo 1 || echo 0)
        else
            #listed=$(ip6tables-save | grep "s ${1}/" | grep "trap on port" | wc -l)
            listed=$(ipset test port_trap_v6 "${1}" 2>/dev/null && echo 1 || echo 0)
        fi
        if [[ "${listed}" == "0" ]]; then
            banned=1
            if [[ "$(echo ${1} | grep ':' | wc -l)" == "0" ]]; then
                logger -t port_trap.py "Ban IPv4: ${1}"
                ipset add port_trap "${1}"
                #iptables -A INPUT -s "${1}/32" -m comment --comment "trap on port ${2}" -j DROP;
            else
                logger -t port_trap.py "Ban IPv6: ${1}"
                ipset add port_trap_v6 "${1}"
                #ip6tables -A INPUT -s "${1}/128" -m comment --comment "trap on port ${2}" -j DROP;
            fi
        fi
    fi
else
    for i in $(sqlite3 -list "${thisdir}/datatrap.db" "select id,ip,port,inet from ips where banned=1 and delafter < $(date +%s)" 2>/dev/null | tail -n+2); do
        ipid=$(echo ${i}| awk -F '|' '{print $1}'); 
        ipip=$(echo ${i}| awk -F '|' '{print $2}');
        ipport=$(echo ${i}| awk -F '|' '{print $3}');
        ipinet=$(echo ${i}| awk -F '|' '{print $4}');
        sqlite3 "${thisdir}/datatrap.db" "update ips set banned=0 where id='${ipid}'" 2>/dev/null
        if [[ "${ipinet}" == "4" ]]; then
            listed=$(ipset test port_trap "${ipip}" 2>/dev/null && echo 1 || echo 0)
            #listed=$(iptables-save | grep "A INPUT -s ${ipip}/32 -m comment --comment \"trap on port ${ipport}\" -j DROP" | wc -l)
            if [[ "${listed}" != "0" ]]; then
                logger -t port_trap.py "Unban IPv4: ${ipip}"
                ipset del port_trap "${ipip}"
                #iptables -D INPUT -s "${ipip}/32" -m comment --comment "trap on port ${ipport}" -j DROP;
            fi
        else
            listed=$(ipset test port_trap_v6 "${ipip}" 2>/dev/null && echo 1 || echo 0)
            #listed=$(ip6tables-save | grep "A INPUT -s ${ipip}/128 -m comment --comment \"trap on port ${ipport}\" -j DROP" | wc -l)
            if [[ "${listed}" != "0" ]]; then
                logger -t port_trap.py "Unban IPv6: ${ipip}"
                ipset del port_trap_v6 "${ipip}"
                #ip6tables -D INPUT -s "${ipip}/128" -m comment --comment "trap on port ${ipport}" -j DROP;
            fi
        fi
    done

    #permanent_ban
    fpb=$(head -1 "${thisdir}/for_permanent_ban.txt");
    OIFS=${IFS}; IFS=$'\n';
    timestamp_file="${thisdir}/last_full_query_timestamp"
    if [[ -f "$timestamp_file" ]]; then
        last_run=$(head -1 "$timestamp_file")
        current_time=$(date +%s)
        time_diff=$(( current_time - last_run ))
        interval=86400
    else
        time_diff=$((interval + 1))
    fi
    query_after=$(date -d "-2 hours" +%s);
    if (( time_diff > interval )); then
        date +%s > "$timestamp_file"
        query="select ip from ips"
        if ! iptables-save | grep -q -- "-A INPUT -m set --match-set port_trap src -j DROP"; then
            iptables -A INPUT -m set --match-set port_trap src -j DROP
        fi
        if ! iptables-save | grep -q -- "-A INPUT -m set --match-set port_trap_perm src -j DROP"; then
            iptables -A INPUT -m set --match-set port_trap_perm src -j DROP
        fi
        if ! ip6tables-save | grep -q -- "-A INPUT -m set --match-set port_trap_v6 src -j DROP"; then
            ip6tables -A INPUT -m set --match-set port_trap_v6 src -j DROP
        fi
        if ! ip6tables-save | grep -q -- "-A INPUT -m set --match-set port_trap_v6_perm src -j DROP"; then
            ip6tables -A INPUT -m set --match-set port_trap_v6_perm src -j DROP
        fi
    else
        query="select ip from ips where banned != '8' and ts >= '${query_after}'"
    fi
        for i in $(sqlite3 -list "${thisdir}/datatrap.db" "${query}" 2>/dev/null | tail -n+2 | sort | uniq -c); do 
            cnt=$(echo $i|awk '{print $1}'); 
            cip=$(echo $i|awk '{print $2}');
            if [[ "${cnt}" -ge "${fpb}" ]]; then
                wl=$(wlcheck "${cip}");
                #echo "Permanent ban: ${cip}";
                if [[ "$(echo ${cip} | grep ':' | wc -l)" != "0" ]]; then
                    inipt=$(ipset test port_trap_v6_perm "${cip}" 2>/dev/null && echo 1 || echo 0)
                    #inipt=$(ip6tables-save | grep -v grep | grep "${cip}/" | grep 'Permanent trap banned' | wc -l)
                else
                    inipt=$(ipset test port_trap_perm "${cip}" 2>/dev/null && echo 1 || echo 0)
                    #inipt=$(iptables-save | grep -v grep | grep "${cip}/" | grep 'Permanent trap banned' | wc -l)
                fi
                if [[ "${wl}" != "1" && "${inipt}" == "0" ]]; then
                    if [[ "$(echo ${cip} | grep ':' | wc -l)" != "0" ]]; then
                        logger -t port_trap.py "Permanent ban IPv6: ${cip}"
                        ipset add port_trap_v6_perm "${cip}"
                        #ip6tables -A INPUT -s "${cip}/128" -m comment --comment "Permanent trap banned" -j DROP;
                    else
                        logger -t port_trap.py "Permanent ban IPv4: ${cip}"
                        ipset add port_trap_perm "${cip}"
                        #iptables -A INPUT -s "${cip}/32" -m comment --comment "Permanent trap banned" -j DROP;
                    fi
                    sqlite3 "${thisdir}/datatrap.db" "update ips set banned=8 where ip='${cip}'" 2>/dev/null
                fi
            fi
        done
    IFS=${OIFS}
fi
