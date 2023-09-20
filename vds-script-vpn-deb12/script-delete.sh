#!/bin/bash
SECONDS=0
printf "\033c"
echo "Removing packages..."
apt purge openvpn asterisk fail2ban chrony -y
apt autoclean && apt clean
rm -R /etc/openvpn
rm ~/ruleset.nft
apt autoremove -y
echo
echo "***** REMOVAL COMPLETED in $SECONDS seconds *****"
echo