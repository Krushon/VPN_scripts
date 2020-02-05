#!/bin/bash
SECONDS=0
printf "\033c"
echo "Install requirements packages..."
apt-get update
apt-get install mc chrony fail2ban mutt mailutils gpgsm -y
apt-get install iptables-persistent xl2tpd libgmp3-dev gawk flex bison make libc6-dev devscripts libssl-dev -y
apt-get autoclean && apt-get clean
systemctl enable chrony
# Изменяем временную зону
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
# устанавливаем openswan
wget https://download.openswan.org/openswan/openswan-latest.tar.gz
tar -xvzf openswan-latest.tar.gz
rm openswan-latest.tar.gz
#cd openswan-2.6.51.5
openswandir=`find . -type d -name 'openswan' | awk -F/ 'NR == 1{print$2}'`
cd $openswandir
make programs
make install
echo
echo -e "***** Script \033[33;1m2\033[0m of \033[33;1m3\033[0m COMPLETED in $SECONDS seconds *****"
echo
