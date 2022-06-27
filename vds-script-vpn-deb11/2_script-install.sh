#!/bin/bash
SECONDS=0
printf "\033c"
echo "Install requirements packets..."
apt-get update
apt-get install openvpn asterisk mc chrony fail2ban nftables -y
apt-get autoclean && apt-get clean
systemctl enable chrony
# Changing the time zone. Изменяем временную зону
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
# Getting ready to generate certificates. Готовимся к генерации сертификатов
mkdir /etc/openvpn/easy-rsa
# Allow packets to be forwarded from one network to another. Разрешаем переcылать пакеты из одной сети в другую.
sed -i '28s/.*net.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
echo
echo -e "***** Script \033[33;1m2\033[0m of \033[33;1m3\033[0m COMPLETED in $SECONDS seconds *****"
echo
