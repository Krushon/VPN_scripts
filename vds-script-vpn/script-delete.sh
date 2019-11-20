#!/bin/bash
SECONDS=0
printf "\033c"
echo "Removing packages..."
apt-get purge openvpn asterisk mc ntpdate ntp -y
apt-get autoclean && apt-get clean
rm -R /etc/openvpn
rm /etc/iptables.rules
apt autoremove -y
echo
echo "***** REMOVAL COMPLETED in $SECONDS seconds *****"
echo
