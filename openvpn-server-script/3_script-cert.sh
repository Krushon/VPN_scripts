#!/bin/bash
# Скрипт запускается один раз, чтобы выпустить серверные сертификаты.
# Генерируем необходимые сертификаты для VPN.
SECONDS=0
printf "\033c"
echo "Выписываем сертификаты..."
echo
echo "Введите ip-адрес вашего mail-сервера"
echo "Enter the \"mailip\" "
read mailip
sed -i '64s/US/RU/' /etc/openvpn/easy-rsa/vars
sed -i '65s/CA/MSK/' /etc/openvpn/easy-rsa/vars
sed -i '66s/SanFrancisco/Moscow/' /etc/openvpn/easy-rsa/vars
#sed -i '67s/Fort-Funston/MyCompany/' /etc/openvpn/easy-rsa/vars
#sed -i "68s/me@myhost.mydomain/${email}/" /etc/openvpn/easy-rsa/vars
#sed -i '69s/MyOrganizationalUnit/IT/' /etc/openvpn/easy-rsa/vars
echo
#получение имени сетевого интерфейса (eth0, ens32, eno1 и т.д.)
net=`ip r | grep default | grep -Po '(?<=dev )(\S+)'`
#получение ip-адреса сетевого интерфейса $net
vdsip=`ip addr show $net | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}'`
#получение имени хоста
hostname=`hostname`

EASYRSAPATH=/etc/openvpn/easy-rsa
KEYSPATH=/etc/openvpn/easy-rsa/keys

# Настраиваем отправку по почте готовых сертификатов пользователей
mv /etc/exim4/update-exim4.conf.conf /etc/exim4/update-exim4.conf.conf.bak
touch /etc/exim4/update-exim4.conf.conf
chmod 644 /etc/exim4/update-exim4.conf.conf
echo -en "dc_eximconfig_configtype='smarthost'\ndc_other_hostname='$hostname.local'\n" >> /etc/exim4/update-exim4.conf.conf
echo -en "dc_local_interfaces='127.0.0.1 ; ::1'\ndc_realhost=''\ndc_relay_domains=''\n" >> /etc/exim4/update-exim4.conf.conf
echo -en "dc_minimaldns='false'\ndc_relay_nets=''\ndc_smarthost='$mailip'\n" >> /etc/exim4/update-exim4.conf.conf
echo -en "CFILEMODE='644'\ndc_use_split_config='true'\ndc_hide_mailname='false'\n" >> /etc/exim4/update-exim4.conf.conf
echo -en "dc_mailname_in_oh='true'\ndc_localdelivery='mail_spool'\n" >> /etc/exim4/update-exim4.conf.conf

cd $EASYRSAPATH
source vars
./clean-all
printf "\033c"
echo
echo "1. Генерация корневого сертификата..."
echo
echo -en "\n\n\n\n\n\n\n\n" | ./build-ca
printf "\033c"
echo
echo -e "1. Генерация корневого сертификата. \033[32;1mOk\033[0m"
echo -e "2. Генерация серверного сертификата..."
echo
(echo -en "\n\n\n\n\n\n\n\n"; sleep 1; echo -en "\n"; sleep 1; echo -en "\n"; sleep 3; echo -en "y"; echo -en "\n"; sleep 3; echo -en "y"; echo -en "\n") | ./build-key-server $company-server
printf "\033c"
echo
echo -e "1. Генерация корневого сертификата. \033[32;1mOk\033[0m"
echo -e "2. Генерация серверного сертификата. \033[32;1mOk\033[0m"
echo -e "3. Генерация клиентского сертификата..."
echo
(echo -en "\n\n\n\n\n\n\n\n"; sleep 1; echo -en "\n"; sleep 1; echo -en "\n"; sleep 3; echo -en "y"; echo -en "\n"; sleep 3; echo -en "y"; echo -en "\n") | ./build-key $company-user
printf "\033c"
echo
echo -e "1. Генерация корневого сертификата. \033[32;1mOk\033[0m"
echo -e "2. Генерация серверного сертификата. \033[32;1mOk\033[0m"
echo -e "3. Генерация клиентского сертификата. \033[32;1mOk\033[0m"
echo -e "4. Генерация ключа Диффи-Хэлмана и ключа для TLS-аутентификации..."
echo
./build-dh
openvpn --genkey --secret keys/$company-ta.key
#mv /etc/openvpn/easy-rsa/keys/ca.crt /etc/openvpn/easy-rsa/keys/$company-ca.crt
#mkdir /etc/openvpn/user
cd $KEYSPATH
cp server.crt server.key ca.crt dh2048.pem ta.key /etc/openvpn
#указываем СВОИ подсети
#echo -en "ifconfig-push 10.5.0.4 10.5.0.1\niroute 192.168.102.0 255.255.255.0\niroute 192.168.10.0 255.255.255.0\niroute 192.168.2.0 255.255.255.0\n" >> /etc/openvpn/ccd/user
touch /etc/openvpn/server.conf
echo -en "port 1194\nproto tcp\ndev tun\nca ca.crt\ncert server.crt\n" >> /etc/openvpn/server.conf
echo -en "key server.key\ndh dh2048.pem\nserver 10.5.0.0 255.255.255.0\n" >> /etc/openvpn/server.conf
echo -en "ifconfig-pool-persist ipp.txt\npush \042dhcp-option DNS 8.8.8.8\042\n" >> /etc/openvpn/server.conf
echo -en "push \042route 192.168.102.0 255.255.255.0\042\n#push \042route 192.168.10.0 255.255.255.0\042\n" >> /etc/openvpn/server.conf
echo -en "#push \042route 192.168.2.0 255.255.255.0\042\nkeepalive 10 120\n" >> /etc/openvpn/server.conf
echo -en "tls-auth ta.key 0\ncipher DES-EDE3-CBC\ncomp-lzo\n;max-clients 100\n" >> /etc/openvpn/server.conf
echo -en "persist-key\npersist-tun\nstatus openvpn-status.log\nlog /var/log/openvpn.log\n" >> /etc/openvpn/server.conf
echo -en "verb 3\nmanagement 127.0.0.1 7505" >>/etc/openvpn/server.conf
# ****************************************************************
# ****Генерация rc.local и iptables.rules ************************
rm /etc/rc.local
touch /etc/rc.local
chmod 755 /etc/rc.local
echo -en "#!/bin/sh -e\niptables-restore < /etc/iptables.rules\nexit 0\n" >> /etc/rc.local
touch /etc/iptables.rules
echo -en "*mangle\n:PREROUTING ACCEPT [44213:4111894]\n:INPUT ACCEPT [22109:2121408]\n:FORWARD ACCEPT [0:0]\n:OUTPUT ACCEPT [222:25744]\n:POSTROUTING ACCEPT [222:25744]\nCOMMIT\n" >> /etc/iptables.rules
echo -en "*filter\n:INPUT DROP [21121:2005015]\n:FORWARD ACCEPT [0:0]\n:OUTPUT ACCEPT [222:25744]\n" >> /etc/iptables.rules
echo -en "-A INPUT -i tun0 -j ACCEPT\n-A INPUT -i lo -j ACCEPT\n-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT\n-A INPUT -p tcp -m tcp --dport 22 -j ACCEPT\n" >> /etc/iptables.rules
echo -en "-A INPUT -p tcp -m tcp --dport 1194 -j ACCEPT\n#-A INPUT -s 192.168.10.0/24 -p udp -m udp --dport 5060 -j ACCEPT\n#-A INPUT -s 192.168.2.0/24 -p udp -m udp --dport 5060 -j ACCEPT\n" >> /etc/iptables.rules
echo -en "#-A INPUT -s 192.168.10.0/24 -p udp -m udp --dport 4569 -j ACCEPT\n#-A INPUT -s 192.168.2.0/24 -p udp -m udp --dport 4569 -j ACCEPT\n" >> /etc/iptables.rules
echo -en "-A INPUT -p udp -m udp --dport 10000:20000 -j ACCEPT\n-A INPUT -p icmp -m icmp --icmp-type 0 -j ACCEPT\n-A INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT\n" >> /etc/iptables.rules
echo -en "COMMIT\n##############\n*nat\n:PREROUTING ACCEPT [8279:852947]\n:OUTPUT ACCEPT [0:0]\n:POSTROUTING ACCEPT [0:0]\n" >> /etc/iptables.rules
echo -en "-A POSTROUTING -o $net -j SNAT --to-source $vdsip\nCOMMIT\n*raw\n:PREROUTING ACCEPT [44288:4119009]\n:OUTPUT ACCEPT [222:25744]\nCOMMIT\n" >> /etc/iptables.rules
# ****************************************************************
echo
echo -e "***** Script \033[33;1m3\033[0m of \033[33;1m3\033[0m COMPLETED in $SECONDS seconds *****"
echo
