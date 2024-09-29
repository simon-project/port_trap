#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import socket, time, sys, os, datetime, sqlite3, re, syslog

ban = 'bash ban.sh'

try:
    sys.argv[1]
    pattern = re.compile("^([0-9:\.a-zA-Z]{1,38})$")
    if not pattern.match(str(sys.argv[1])):
        print('Use: port_trap.py PORT BANTIME\nFor example: port_trap.py 9090\nPort and BANTIME it is DIGITS')
        exit(1)
except IndexError:
    print('Use: port_trap.py PORT BANTIME\nFor example: port_trap.py 9090 3600')
    exit(1)
try:
    sys.argv[2]
    pattern = re.compile("^([0-9]{1,5})$") 
    if not pattern.match(str(sys.argv[2])): 
        print('Use: port_trap.py PORT BANTIME\nFor example: port_trap.py 9090\nPort and BANTIME it is DIGITS')
        exit(1) 
except IndexError:
    print('Use: port_trap.py PORT BANTIME\nFor example: port_trap.py 9090 3600')
    exit(1) 
try:
    sys.argv[3]
    inet=6
except IndexError:
    inet=4
slcon = sqlite3.connect('datatrap.db')
sl = slcon.cursor()
sl.execute('CREATE TABLE IF NOT EXISTS ips (id INTEGER PRIMARY KEY, ts INTEGER, delafter INTEGER, ip TEXT, port INTEGER, detected TEXT, banned INTEGER, inet INTEGER)')
slcon.commit()
slcon.close()


def check_wl(ip_to_check):
    matched=False
    with open('whitelist.txt', 'r') as f:
        regex_patterns = f.readlines()
    for pattern in regex_patterns:
        pattern = pattern.strip()
        if not pattern or pattern.startswith('#'):
            continue
        try:
            regex = re.compile(pattern)
            if regex.match(ip_to_check):
                matched=True
        except re.error:
            syslog.openlog(ident="port_trap.py", logoption=syslog.LOG_PID, facility=syslog.LOG_USER)
            syslog.syslog(syslog.LOG_ERR, "ERROR: Incorrect regex pattern in whitelist.txt: "+str(pattern))
            syslog.closelog()
            print(f"Некорректное регулярное выражение: {pattern}")
            matched=False
    return matched

def extract_ip_and_port(ip_with_port):
    ip, port = ip_with_port.rsplit(':', 1)
    return ip, int(port)

if ':' in str(sys.argv[1]):
    trap_addr, trap_port = extract_ip_and_port(str(sys.argv[1]))
else:
    trap_port=int(sys.argv[1])
    if inet==4:
        trap_addr='0.0.0.0'
    else:
        trap_addr='::'

pattern = re.compile("^([0-9]{1,5})$")
if not pattern.match(str(trap_port)):
    print('Use: port_trap.py PORT BANTIME\nFor example: port_trap.py 9090\nPort and BANTIME it is DIGITS')
    exit(1)

syslog.openlog(ident="port_trap.py", logoption=syslog.LOG_PID, facility=syslog.LOG_USER)
syslog.syslog(syslog.LOG_INFO, "Trap started on IPv"+str(inet)+" "+trap_addr+":"+str(trap_port))
syslog.closelog()
while True:
    if inet==4:
        sock = socket.socket(family=socket.AF_INET)
    else:
        sock = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
        sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind((trap_addr, trap_port))
    sock.listen(32)
    conn, addr = sock.accept()
    time.sleep(0.1)
    conn.close()
    time.sleep(0.1)
    if check_wl(addr[0]):
        syslog.openlog(ident="port_trap.py", logoption=syslog.LOG_PID, facility=syslog.LOG_USER)
        syslog.syslog(syslog.LOG_NOTICE, 'WHITELISTED trap touched on port '+str(trap_port)+': '+str(addr[0]))
        syslog.closelog()
    else:
        syslog.openlog(ident="port_trap.py", logoption=syslog.LOG_PID, facility=syslog.LOG_USER)
        syslog.syslog(syslog.LOG_NOTICE, 'Trap touched on port '+str(trap_port)+': '+str(addr[0]))
        syslog.closelog()
        slcon = sqlite3.connect('datatrap.db')
        sl = slcon.cursor()
        sl.execute("select count(id) from ips where ip='"+str(addr[0])+"'")
        indb=int(sl.fetchone()[0])
        indb+=1
        indb = indb * indb
        btimeout=int(sys.argv[2]) * indb
        sl.execute("insert into ips (ts, delafter, ip, port, detected, banned, inet) values ('"+str(int(time.time()))+"','"+str((int(time.time())+int(btimeout)))+"','"+str(addr[0])+"','"+str(sys.argv[1])+"','"+str(datetime.datetime.now())+"','1','"+str(inet)+"')")
        slcon.commit()
        slcon.close()
        os.system(str(ban)+" "+str(addr[0])+" "+str(trap_port))
