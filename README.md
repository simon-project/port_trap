# Port Trap

## Лирическое отступление
Представляете ли вы, сколько ботов ежечасно сканируют порты каждого доступного в сети сервера, в поисках уязвимостей? 
Сколько лишних запросов вынужден обрабатывать каждый сервер, сколько гигабайт ненужной информации записывается в логи из-за множества неудачных попыток авторизации?

Всё просто. Если кто-то пытается войти в окно, игнорируя дверь или заглядывает в окно, игнорируя чужую приватность - заблокировать его. Сначала временно - он мог сделать это по ошибке. Но если он продолжит - заблокировать уже навсегда. Port Trap выполняет именно эту функцию - вы просто сообщаете ему порты, которые он должен слушать и каждый, кто подключится к перечисленным портам будет заблокирован.

## Требования

ОС Linix, systemd, iptables, ipset, sqlite3, python3, cron/crontab, ip.

## Установка

```
cd /opt
git clone https://github.com/simon-project/port_trap.git
cd port_trap
chmod +x ./install.sh
./install.sh
```

## Настройка

### Файл list_of_ports.txt

В этом файле, по одному на строку, задается список портов для установки ловушек, в следующем формате:

```
Порт#Таймаут блокировки в секундах#6 для ловушки на порту IPv6
```
Также, перед портом можно указать конкретный IP-адрес, чтобы ловушка была установлена
не на все доступные IP-адреса сервера, а лишь на указанные. 
Таким образом, для установки ловушки на порт 9090 протокола IPv4 для всех достуных адресов, с таймаутом в один час:
```
9090#3600
```
Тоже самое, для протокола IPv6:
```
9090#3600#6
```
Для установки ловушки на конкретный IPv4-адрес, например на 12.34.56.78:
```
12.34.56.78:9090#3600
```
Фрагмент содержимого данного файла:
```
#PORT#TIMEOUT_IN_SECONDS#6 if this trap for IPv6
#3600 it is 1 hour, 86400 it is one day
23#3600
23#3600#6
83#3600
83#3600#6
223#3600
223#2600#6
3389#3600
3389#3600#6
5050#3600
5050#3600#6
```
Для успешной установки ловушки на порт, этот порт должен быть свободным. Проверить свободен ли порт, можно при помощи команды **lsof**, например:
```
lsof -i :3600
```
Если порт свободен - команда ничего не покажет. Если порт занят - покажет чем именно он занят.
#### Почему порты для IPv4 и IPv6 требуется указывать отдельно?

Модуль протокола IPv6 позволяет занять указанный порт одновременно, как для IPv6, так и для IPv4 - такая возможность выглядит удобной, ровно до того момента, пока не потребуется занять порт используя один протокол и не занимать этот порт с использованием другого. Таким образом, необходимость отдельно перечислять порты для протоколов IPv4 и IPv6, хоть и выглядит утомительной, обусловлена обеспечением максимального контроля.

### Файл for_permanent_ban.txt

В данном файле указывается количество банов для IP-адреса, после которых данный IP будет заблокирован перманентно. Например:
```
3
```
В этом случае, если один и тот же IP будет забанен три раза, доступ для него уже не будет разблокирован. 

### Файл whitelist.txt

В этом файле можно перечислить IP-адреса, которые не должны блокироваться. 
Допускаются регулярные выражения, например:
```
12.34.56.*
34.56.78.[2-9]
78.56.*.*
1\.2\.3\.[0-9]{1,3}
2a03:*:*:*::*
```
**Не допускается указание масок типа /32 или /128**

## Использование

Когда установка выполнена, для запуска и установки ловушек, используйте команду:

```
systemctl start port_trap
```
Для просмотра статуса:
```
systemctl status port_trap
```
Для остановки:
```
systemctl stop port_trap
```
Для перезапуска:
```
systemctl restart port_trap
```

После того, как сервис запущен и ловушки установлены, любое подключение на любой из перечисленных портов приведет к блокировке IP-адреса, с которого было выполнено подключение, на срок указанный в таймауте для данного конкретного порта. Блокировка не будет выполнена лишь в случае, если подключение было выполненно с IP-адреса присутствующего в файле whitelist.txt или с одного из локальных IP-адресов текущего сервера.

По истечению таймаута, блокировка будет снята. В случае повторного подключения с того же IP на порт любой из ловушек, блокировка будет установлена вновь, однако таймаут будет увеличен в квадратичной прогрессии, т.е. при второй блокировке, таймаут будет увеличен по формуте `Timeout = Timeout * (2*2)`, при третьей блокировке, таймаут увеличивается по формуле `Timeout = Timeout * (3*3)` и так далее, при достижении количества блокировок указанного в файле for_permanent_ban.txt - данный IP будет заблокирован перманентно.

Блокировки выполняются при помощи iptables в связке с ipset для наилучшей производительности.

### Файл show.sh

Запустив скрипт `show.sh` в каталоге port_trap можно увидеть содержимое базы IP-адресов попавших в ловушки.

Запуск `show.sh banned` покажет IP-адреса временно заблокированные в текущий момент.

Запуск `show.sh cnt` покажет количество выполненных блокировок для каждого адреса в базе.

Адреса заблокированные перманентно при помощи `show.sh` не отображаются, однако, по количеству блокировок в базе можно понять, какие адреса уже находятся в перманентном бане.

### Логи

Сервис записывает информацию в системный лог. Посмотреть лог сервиса можно при помощи команды:
```
journalctl -t port_trap.py
```
В лог записывается информация о запуске сервиса (об установке ловушек), о срабатывании ловушек, блокировке IP-адресов, разблокировке IP-адресов, о пермантном бане и об остановке сервиса.

### Удаление

```
systemctl stop port_trap
cd /opt/port_trap
./install.sh --uninstall
rm -rf /opt/port_trap
```

## P.S. 

Автор не является профессиональным разработчиком и великим знатоком.
Разработки автора создаются в результате возникновения той или иной
задачи и отсутствия уже готовых простых решений, либо в случаях, когда
такие решения не удалось найти или они оказались слишком сложными или
громоздкими.
Возможно, вы найдете здесь "велосипед", причем не самой удачной
конструкции, изобретенный заново ввиду того, что стандартные решения
показались слишком сложными, либо здесь могут обнаружиться "костыли",
которые не выглядят хорошо, но тем не менее позволяют передвигаться.
Использовать ли это — решать вам.

# English version

## Lyrical Digression
Can you imagine how many bots constantly scan the ports of every accessible server on the network in search of vulnerabilities? 
How many unnecessary requests must each server handle, and how many gigabytes of unnecessary information are written to the logs due to numerous failed authentication attempts?

It’s simple. If someone is trying to enter through a window, ignoring the door, or peering through a window, ignoring someone else's privacy—block them. First, temporarily—they might have done it by mistake. But if they continue—block them permanently. Port Trap performs exactly this function—you simply inform it of the ports it should listen to, and anyone who connects to those ports will be blocked.

## Requirements

Linux OS, systemd, iptables, ipset, sqlite3, python3, cron/crontab, ip.

## Installation

```
cd /opt
git clone https://github.com/simon-project/port_trap.git
cd port_trap 
chmod +x ./install.sh
./install.sh
```

## Configuration

### The list_of_ports.txt File

This file contains a list of ports for setting traps, one per line, in the following format:

```
Port#Timeout in seconds#6 for IPv6 port trap
```
Additionally, a specific IP address can be specified before the port to set the trap not on all available IP addresses of the server but only on the specified ones. Thus, to set a trap on port 9090 for the IPv4 protocol for all available addresses, with a timeout of one hour:
```
9090#3600
```
The same applies for the IPv6 protocol:
```
9090#3600#6
```
To set a trap on a specific IPv4 address, for example, 12.34.56.78:
```
12.34.56.78:9090#3600
```
A fragment of the content of this file:
```
#PORT#TIMEOUT_IN_SECONDS#6 if this trap for IPv6
#3600 it is 1 hour, 86400 it is one day
23#3600
23#3600#6
83#3600
83#3600#6
223#3600
223#2600#6
3389#3600
3389#3600#6
5050#3600
5050#3600#6
```
For a trap to be successfully set on a port, that port must be free. You can check if the port is free using the **lsof** command, for example:
```
lsof -i :3600
```

If the port is free, the command will show nothing. If the port is occupied, it will indicate what is occupying it.

#### Why do we need to specify ports for IPv4 and IPv6 separately?

The IPv6 protocol module allows a specified port to be occupied simultaneously for both IPv6 and IPv4—this feature seems convenient until the moment comes when one needs to occupy a port using one protocol while not occupying that port with another. Thus, the necessity to separately list ports for IPv4 and IPv6, though it seems tedious, is dictated by the need for maximum control.

### The for_permanent_ban.txt File

This file specifies the number of bans for an IP address after which that IP will be blocked permanently. For example:

```
3
```
In this case, if the same IP is banned three times, access will not be restored.

### The whitelist.txt File

This file can list IP addresses that should not be blocked. 
Regular expressions are allowed, for example:
```
12.34.56.*
34.56.78.[2-9]
78.56.*.*
1\.2\.3\.[0-9]{1,3}
2a03:*:*:*::*
```
**Mask types like /32 or /128 are not allowed**

## Usage

When the installation is complete, to start and set the traps, use the command:
```
systemctl start port_trap
```
To view the status:
```
systemctl status port_trap
```
To stop:
```
systemctl stop port_trap
```
To restart:
```
systemctl restart port_trap
```

Once the service is started and the traps are set, any connection to any of the specified ports will lead to the blocking of the IP address from which the connection was made, for the duration specified in the timeout for that particular port. Blocking will not occur only if the connection was made from an IP address present in the whitelist.txt file or from one of the local IP addresses of the current server.

After the timeout has expired, the blocking will be lifted. In the case of a repeated connection from the same IP to any of the traps, blocking will be established again, but the timeout will increase in a quadratic progression, i.e., upon the second blocking, the timeout will increase according to the formula `Timeout = Timeout * (2*2)`, upon the third blocking, the timeout increases according to the formula `Timeout = Timeout * (3*3)` etc, and when the number of blocks indicated in the for_permanent_ban.txt file is reached, that IP will be permanently blocked.

Blocking is carried out using iptables with ipset for improved performance.

### The show.sh File

Running the script `show.sh` in the port_trap directory allows you to see the contents of the IP address database that have fallen into traps.

Running `show.sh banned` will show the IP addresses temporarily blocked at the moment.

Running `show.sh cnt` will show the number of blocks performed for each address in the database.

Addresses blocked permanently are not displayed by show.sh; however, by the number of blocks in the database, one can understand which addresses are already in permanent ban.

### Logs

The service logs information in the system log. You can view the service log using the command:
```
journalctl -t port_trap.py
```
The log records information about the service startup (trap installation), trap triggers, IP address blockings, IP address unblocking, permanent bans, and service shutdown.

### Uninstall

```
systemctl stop port_trap
cd /opt/port_trap
./install.sh --uninstall
rm -rf /opt/port_trap
```

## P.S.

The author is not a professional developer or a great expert.
The author's developments arise from the emergence of certain tasks and
the absence of ready-made simple solutions, or in cases where such
solutions could not be found or turned out to be too complex or
cumbersome.

You may find here a "bicycle," and not of the most successful design,
reinvented because standard solutions seemed too complicated, or you may
discover "workarounds" that do not look good but nonetheless allow for
movement. Whether to use this is up to you.




