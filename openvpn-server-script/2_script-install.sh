#!/bin/bash
SECONDS=0
printf "\033c"
echo "Install requirements packets..."
apt-get update
apt-get install openvpn mc chrony nftables mutt mailutils gpgsm -y
apt-get autoclean && apt-get clean
apt-mark auto gpgsm
systemctl enable chrony
# Изменяем временную зону
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
# Готовимся к генерации сертификатов
mkdir /etc/openvpn/easy-rsa
# Разрешаем переcылать пакеты из одной сети в другую.
sed -i '28s/.*net.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
echo
echo -en "\e[1;31mДля отправки почты необходимо настроить /etc/exim4/update-exim4.conf.conf\e[0m"
echo
echo -e "***** Script \033[33;1m2\033[0m of \033[33;1m3\033[0m COMPLETED in $SECONDS seconds *****"
echo
