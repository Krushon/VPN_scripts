#!/bin/bash
SECONDS=0
printf "\033c"
echo "Removing packages..."
apt-get purge openvpn asterisk ntp chrony fail2ban nftables -y
apt-get autoclean && apt-get clean
rm -R /etc/openvpn
rm ~/ruleset.nft
apt autoremove -y
echo
echo "***** REMOVAL COMPLETED in $SECONDS seconds *****"
echo