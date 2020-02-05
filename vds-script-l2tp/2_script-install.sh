#!/bin/bash
SECONDS=0
printf "\033c"
echo "Install requirements packets..."
apt-get update
apt-get install mc chrony fail2ban -y
apt-get install iptables-persistent xl2tpd libgmp3-dev gawk flex bison make libc6-dev devscripts libssl-dev -y
apt-get autoclean && apt-get clean
systemctl enable chrony
# устанавливаем openswan
wget https://download.openswan.org/openswan/openswan-latest.tar.gz
tar -xvzf openswan-latest.tar.gz
rm openswan-latest.tar.gz
openswandir=`find . -type d -name 'openswan' | awk -F/ 'NR == 1{print$2}'`
cd $openswandir
make programs
make install

# Изменяем временную зону
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
# Разрешаем переcылать пакеты из одной сети в другую.
sed -i '28s/.*net.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
echo
echo -e "***** Script \033[33;1m2\033[0m of \033[33;1m3\033[0m COMPLETED in $SECONDS seconds *****"
echo
