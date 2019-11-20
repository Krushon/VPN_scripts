#!/bin/bash
# Устанавливаем пакеты OpenVPN, Asterisk, MidnightCommander и NTP для синхронизации часов.
SECONDS=0
printf "\033c"
echo "Устанавливаем необходимое ПО..."
apt-get update
apt-get install openvpn asterisk mc ntp ntpdate net-tools fail2ban -y
apt-get autoclean && apt-get clean
/etc/init.d/ntp stop && ntpdate pool.ntp.org && /etc/init.d/ntp start
# Изменяем временную зону
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
# Готовимся к генерации сертификатов
mkdir /etc/openvpn/easy-rsa
cp -r /usr/share/easy-rsa/* /etc/openvpn/easy-rsa
ln -s /etc/openvpn/easy-rsa/openssl-1.0.0.cnf /etc/openvpn/easy-rsa/openssl.cnf
# Разрешаем форвардить пакеты из одной сети в другую.
sed -i '28s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
echo
echo -e "***** Script \033[33;1m2\033[0m of \033[33;1m3\033[0m COMPLETED in $SECONDS seconds *****"
echo
