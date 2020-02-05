#!/bin/bash
# Генерируем необходимые ключи и конфиги для VPN.
SECONDS=0
printf "\033c"
echo "Enter the new \"PSKKEY\" "
read PSKKEY
# Получаем имя сетевого интерфейса (eth0, ens32, eno1 и т.д.)
NET=`ip r | grep default | grep -Po '(?<=dev )(\S+)'`
# Получаем ip-адрес сетевого интерфейса $net
VDSIP=`ip addr show $NET | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}'`

## Настройка ipsec
# Генерируем конфиг ipsec
mv /etc/ipsec.conf /etc/ipsec.conf.bak && chmod 644 /etc/ipsec.conf.bak
touch /etc/ipsec.conf && chmod 755 /etc/ipsec.conf
echo -en "version 2.0\nconfig setup\n" >> /etc/ipsec.conf
echo -en "\tnat_traversal=yes\n\tvirtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12\n" >> /etc/ipsec.conf
echo -en "\toe=off\n\tprotostack=netkey\n\tnhelpers=0\n\t;\n\tconn L2TP-PSK-NAT\n" >> /etc/ipsec.conf
echo -en "\trightsubnet=vhost:%priv\n\talso=L2TP-PSK-noNAT\n\t;\n\tconn L2TP-PSK-noNAT\n" >> /etc/ipsec.conf
echo -en "\tauthby=secret\n\tpfs=no\n\tauto=add\n\tkeyingtries=3\n\trekey=no\n" >> /etc/ipsec.conf
echo -en "\tdpddelay=30\n\tdpdtimeout=120\n\tdpdaction=clear\n\tikelifetime=8h\n" >> /etc/ipsec.conf
echo -en "\tkeylife=1h\n\ttype=transport\n\tleft=$VDSIP\n\tleftprotoport=17/1701\n" >> /etc/ipsec.conf
echo -en "\tright=%any\n\trightprotoport=17/%any\nforceencaps=yes\n" >> /etc/ipsec.conf
# Указываем PSK ключ для ipsec
touch /etc/ipsec.secrets
echo -en "$VDSIP %any: PSK \042$PSK-KEY\042" >> /etc/ipsec.secrets

## Настройка l2tp
mv /etc/xl2tpd/xl2tpd.conf /etc/xl2tpd/xl2tpd.conf.bak
touch /etc/xl2tpd/xl2tpd.conf
echo -en "[global]\n\tlisten-addr = $VDSIP\n\tport = 1701\n\tipsec saref = no\n" >> /etc/ixl2tpd/xl2tpd.conf
echo -en "\tdebug tunnel = yes\n\tdebug avp = yes\n\tdebug packet = yes\n" >> /etc/ixl2tpd/xl2tpd.conf
echo -en "\tdebug network = yes\n\tdebug state = yes\n\tauth file = /etc/ppp/chap-secrets\n" >> /etc/ixl2tpd/xl2tpd.conf
echo -en "\t;\n\t[lns default]\n\tip range = 172.16.254.1-172.16.254.253 ; Диапазон IP-адресов, которые выдаются подключающимся клиентам\n" >> /etc/ixl2tpd/xl2tpd.conf
echo -en "\tlocal ip = 172.16.254.254 ; Локальный IP-адрес сервера для VPN-клиентов\n" >> /etc/ixl2tpd/xl2tpd.conf
echo -en "\trefuse chap = yes\n\trefuse pap = yes\n\trequire authentication = yes\n" >> /etc/ixl2tpd/xl2tpd.conf
echo -en "\tppp debug = yes\n\tpppoptfile = /etc/ppp/options.xl2tpd\n\tlength bit = yes\n" >> /etc/ixl2tpd/xl2tpd.conf
echo -en "\tname = VPN\nassign ip = yes\n" >> /etc/ixl2tpd/xl2tpd.conf

## Настройка ppp
touch /etc/ppp/options.xl2tpd
echo -en "require-mschap-v2\n\trefuse-mschap\n\tms-dns 8.8.8.8\n\tms-dns 8.8.4.4\n" >> /etc/ppp/options.xl2tpd
echo -en "\tasyncmap 0\n\tauth\n\tcrtscts\n\tidle 1800\n\tmtu 1200\n\tmru 1200\n" >> /etc/ppp/options.xl2tpd
echo -en "\tlock\n\thide-password\n\tlocal\n\tdebug\n\tname VPN\n" >> /etc/ppp/options.xl2tpd
echo -en "\tproxyarp\n\tlcp-echo-interval 30\nlcp-echo-failure 4\n" >> /etc/ppp/options.xl2tpd

## Настройка файрвола
iptables -t nat -A POSTROUTING -o venet0:0 -s 172.16.254.0/24 -j MASQUERADE
iptables -t nat -A POSTROUTING -o venet0 -s 172.16.254.0/24 -j MASQUERADE
iptables -A FORWARD -s 172.16.254.0/24 -j ACCEPT
iptables -A FORWARD -d 172.16.254.0/24 -j ACCEPT
iptables -t nat -A POSTROUTING -o venet0 -s 172.16.254.0/24 -j SNAT --to-source $VDSIP
iptables-save

## Настройка конфига sysctl
# Разрешаем переcылать пакеты из одной сети в другую.
sed -i '28s/.*net.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
# Отключаем ICMP send_ и accept_redirects
sed -i '44s/.*net.*/net.ipv4.conf.all.accept_redirects = 0/' /etc/sysctl.conf
sed -i '52s/.*net.*/net.ipv4.conf.all.send_redirects = 0/' /etc/sysctl.conf
echo -en "\nnet.ipv4.conf.default.send_redirects = 0\nnet.ipv4.conf.default.accept_redirects = 0\n" >> /etc/sysctl.conf
echo -en "net.ipv4.conf.$NET.send_redirects = 0\nnet.ipv4.conf.$NET.accept_redirects = 0\n" /etc/sysctl.conf

## Перезапуск служб
/etc/init.d/ipsec restart
/etc/init.d/xl2tpd restart

# ****************************************************************
echo
echo -e "***** Script \033[33;1m3\033[0m of \033[33;1m3\033[0m COMPLETED in $SECONDS seconds *****"
echo
