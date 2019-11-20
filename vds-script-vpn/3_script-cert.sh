#!/bin/bash
# Генерируем необходимые сертификаты для VPN.
SECONDS=0
printf "\033c"
echo "Выписываем сертификаты..."
echo
echo "Enter the \"company\" "
read company
echo "Enter the \"email\" "
read email
echo "Enter the \"protocol\" (tcp/udp)"
read protocol
echo "Enter the \"tun\" "
read tun
echo "Enter the \"ssh\" port"
read ssh
sed -i "1s/22/${ssh}/" /etc/ssh/sshd_config
sed -i '64s/US/RU/' /etc/openvpn/easy-rsa/vars
sed -i '65s/CA/MSK/' /etc/openvpn/easy-rsa/vars
sed -i '66s/SanFrancisco/Moscow/' /etc/openvpn/easy-rsa/vars
sed -i "67s/Fort-Funston/${company}/" /etc/openvpn/easy-rsa/vars
sed -i "68s/me@myhost.mydomain/${email}/" /etc/openvpn/easy-rsa/vars
sed -i '69s/MyOrganizationalUnit/IT/' /etc/openvpn/easy-rsa/vars
echo
#получение имени сетевого интерфейса (eth0, ens32, eno1 и т.д.)
net=`ip r | grep default | grep -Po '(?<=dev )(\S+)'`
#получение ip-адреса сетевого интерфейса $net
vdsip=`ip addr show $net | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}'`
EASYRSAPATH=/etc/openvpn/easy-rsa
KEYSPATH=/etc/openvpn/easy-rsa/keys
CAUSERPATH=/etc/openvpn/user/
#Генерируем сертификаты
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
mv /etc/openvpn/easy-rsa/keys/ca.crt /etc/openvpn/easy-rsa/keys/$company-ca.crt
mkdir /etc/openvpn/user
cd $KEYSPATH
cp *server.crt *server.key *ca.crt dh2048.pem *ta.key /etc/openvpn
cp *user.crt *user.key *ca.crt *ta.key /etc/openvpn/user
# ****Генерация /ccd и server.conf********************************
mkdir /etc/openvpn/ccd
touch /etc/openvpn/ccd/$company-user
#указываем СВОИ подсети (строка 72, 75)
echo -en "ifconfig-push 10.1.$tun.4 10.1.$tun.1\niroute 10.1.1.0 255.255.255.0\niroute 192.168.102.0 255.255.255.0\n" >> /etc/openvpn/ccd/$company-user
touch /etc/openvpn/server.conf
echo -en "port 1194\nproto $protocol\ndev tun0\nca $company-ca.crt\ncert $company-server.crt\nkey $company-server.key\ndh dh2048.pem\nserver 10.1.$tun.0 255.255.255.0\nclient-config-dir ccd\n" >> /etc/openvpn/server.conf
echo -en "route 10.1.1.0 255.255.255.0\nroute 10.1.$tun.0 255.255.255.0\nroute 192.168.102.0 255.255.255.0 10.1.$tun.2\n" >> /etc/openvpn/server.conf
echo -en "#push \042redirect-gateway def1\042\nkeepalive 10 120\ntls-auth $company-ta.key 0\ncipher DES-EDE3-CBC\ncomp-lzo\npersist-key\npersist-tun\nstatus openvpn-status.log\nlog /var/log/openvpn.log\nverb 3\n" >> /etc/openvpn/server.conf
# ****************************************************************
# ****Генерация rc.local и iptables.rules ************************
rm /etc/rc.local
touch /etc/rc.local
chmod 755 /etc/rc.local
echo -en "#!/bin/sh -e\niptables-restore < /etc/iptables.rules\nexit 0\n" >> /etc/rc.local
touch /etc/iptables.rules
echo -en "*mangle\n:PREROUTING ACCEPT [44213:4111894]\n:INPUT ACCEPT [22109:2121408]\n:FORWARD ACCEPT [0:0]\n:OUTPUT ACCEPT [222:25744]\n:POSTROUTING ACCEPT [222:25744]\nCOMMIT\n" >> /etc/iptables.rules
echo -en "*filter\n:INPUT DROP [21121:2005015]\n:FORWARD ACCEPT [0:0]\n:OUTPUT ACCEPT [222:25744]\n" >> /etc/iptables.rules
echo -en "-A INPUT -i tun0 -j ACCEPT\n-A INPUT -i lo -j ACCEPT\n-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT\n-A INPUT -p tcp -m tcp --dport $ssh -j ACCEPT\n" >> /etc/iptables.rules
echo -en "-A INPUT -p $protocol -m $protocol --dport 1194 -j ACCEPT\n" >> /etc/iptables.rules
echo -en "-A INPUT -s 185.45.152.174/32 -p udp -m udp --dport 5060 -j ACCEPT\n-A INPUT -s 178.16.26.122/32 -p udp -m udp --dport 5060 -j ACCEPT\n-A INPUT -s 176.9.145.115/32 -p udp -m udp --dport 5060 -j ACCEPT\n" >> /etc/iptables.rules
echo -en "-A INPUT -s 5.9.108.25/32 -p udp -m udp --dport 5060 -j ACCEPT\n-A INPUT -s 89.249.23.194/32 -p udp -m udp --dport 5060 -j ACCEPT\n-A INPUT -s 195.122.19.17/32 -p udp -m udp --dport 5060 -j ACCEPT\n" >> /etc/iptables.rules
echo -en "-A INPUT -s 195.122.19.18/32 -p udp -m udp --dport 5060 -j ACCEPT\n-A INPUT -s 195.122.19.19/32 -p udp -m udp --dport 5060 -j ACCEPT\n-A INPUT -s 195.122.19.9/32 -p udp -m udp --dport 5060 -j ACCEPT\n" >> /etc/iptables.rules
echo -en "-A INPUT -s 195.122.19.10/32 -p udp -m udp --dport 5060 -j ACCEPT\n-A INPUT -s 195.122.19.11/32 -p udp -m udp --dport 5060 -j ACCEPT\n-A INPUT -s 91.228.238.172/32 -p udp -m udp --dport 5060 -j ACCEPT\n" >> /etc/iptables.rules
echo -en "-A INPUT -s 185.45.152.128/28 -p udp -m udp --dport 5060 -j ACCEPT\n-A INPUT -s 185.45.152.160/27 -p udp -m udp --dport 5060 -j ACCEPT\n" >> /etc/iptables.rules
echo -en "-A INPUT -p udp -m udp --dport 10000:20000 -j ACCEPT\n-A INPUT -p icmp -m icmp --icmp-type 0 -j ACCEPT\n-A INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT\n" >> /etc/iptables.rules
echo -en "COMMIT\n##############\n*nat\n:PREROUTING ACCEPT [8279:852947]\n:OUTPUT ACCEPT [0:0]\n:POSTROUTING ACCEPT [0:0]\n" >> /etc/iptables.rules
echo -en "-A POSTROUTING -o $net -j SNAT --to-source $vdsip\nCOMMIT\n*raw\n:PREROUTING ACCEPT [44288:4119009]\n:OUTPUT ACCEPT [222:25744]\nCOMMIT\n" >> /etc/iptables.rules
# ****************************************************************
#настройка fail2ban
touch /etc/fail2ban/jail.local
echo -en "[sshd]\nenabled   = true\nfilter    = sshd\nbanaction = iptables-multiport\n" >> /etc/fail2ban/jail.local
echo -en "findtime  = 3600\nmaxretry  = 3\nbantime   = 259200\n\n" >> /etc/fail2ban/jail.local
echo -en "[sshd-ddos]\nenabled   = true\nport      = ssh,sftp\n" >> /etc/fail2ban/jail.local
echo -en "filter    = sshd-ddos\nmaxretry  = 2\n\n" >> /etc/fail2ban/jail.local
echo -en "[asterisk]\nenabled   = true\nfilter    = asterisk\n" >> /etc/fail2ban/jail.local
echo -en "action    = iptables-allports[name=asterisk, protocol=all]\n" >> /etc/fail2ban/jail.local
echo -en "logpath   = /var/log/asterisk/messages\nbantime   = 259200\n" >> /etc/fail2ban/jail.local
/etc/init.d/fail2ban restart
# ****Генерация клиентских конфигов ******************************
touch /etc/openvpn/user/$company-openvpn.log #должен быть пустой
touch /etc/openvpn/user/$company-user.ovpn
echo -en "client\ndev tun$tun\nproto $protocol\nremote $vdsip 1194\nresolv-retry infinite\nnobind\npersist-key\npersist-tun\n" >> /etc/openvpn/user/$company-user.ovpn
echo -en "ca /etc/openvpn/$company/$company-ca.crt\ncert /etc/openvpn/$company/$company-user.crt\nkey /etc/openvpn/$company/$company-user.key\ntls-auth /etc/openvpn/$company/$company-ta.key 1\ncipher DES-EDE3-CBC\n" >> /etc/openvpn/user/$company-user.ovpn
echo -en "ns-cert-type server\ncomp-lzo\nlog /etc/openvpn/$company/$company-openvpn.log\nverb 3\nscript-security 2\nup \042/etc/openvpn/$company/$company-up.sh\042\n" >> /etc/openvpn/user/$company-user.ovpn
touch /etc/openvpn/user/$company-up.sh
echo -en "#!/bin/bash\n/sbin/ip route add default via 10.1.$tun.1 dev tun$tun table $company\n" >> /etc/openvpn/user/$company-up.sh
echo -en "#/sbin/ip rule add from 10.1.1.x table $company #KB\n#/sbin/ip rule add from 192.168.x.x table $company #TXM\n" >> /etc/openvpn/user/$company-up.sh
echo -en "/sbin/ip route flush cache\n" >> /etc/openvpn/user/$company-up.sh
cd $CAUSERPATH
ln -s $company-user.ovpn $company-user.conf
tar -cvf $company.tar *
echo
echo "Клиентские сертификаты и конфиги сгенерированы (8 файлов) и упакованы в архив /etc/openvpn/user/$company.tar. Его нужно скопировать на шлюз."
# ****************************************************************
echo
echo -e "***** Script \033[33;1m3\033[0m of \033[33;1m3\033[0m COMPLETED in $SECONDS seconds *****"
echo
