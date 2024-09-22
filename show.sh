#!/bin/bash

thisdir=$(dirname -- "$(realpath -- "$0")");

if [[ "${1}" == "" || "${1}" == "all" ]]; then
    sqlite3 "${thisdir}/datatrap.db" 'select * from ips'
elif [[ "${1}" == "banned" ]]; then
    sqlite3 "${thisdir}/datatrap.db" "select * from ips where banned='1'"
elif [[ "${1}" == "cnt" || "${1}" == "col" ]]; then
    sqlite3 -list "${thisdir}/datatrap.db" "select ip from ips" 2>/dev/null |tail -n+2| tail -n+2 | sort | uniq -c | sort -nrk1
else
    echo "Use: show.sh all|banned"
fi
