#!/bin/bash
# Генерируем необходимые сертификаты для VPN.
SECONDS=0
printf "\033c"

EASYRSAPATH=/usr/share/easy-rsa/
KEYSPATH=/etc/openvpn/keys/
CLIENTPATH=/etc/openvpn/user/
SERVERPATH=/etc/openvpn/server/

# Уточняем необходииые данные
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

#получение имени сетевого интерфейса (eth0, ens32, eno1 и т.д.)
net=`ip r | grep default | grep -Po '(?<=dev )(\S+)'`
#получение ip-адреса сетевого интерфейса $net
vdsip=`ip addr show $net | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}'`

# Разносим полученные данные по конфигам
sed -i "1s/22/${ssh}/" /etc/ssh/sshd_config

touch /usr/share/easy-rsa/vars
echo -en "export KEY_COUNTRY=\042RU\042\n" >> /usr/share/easy-rsa/vars
echo -en "export KEY_PROVINCE=\042MSK\042\n" >> /usr/share/easy-rsa/vars
echo -en "export KEY_CITY=\042Moscow\042\n" >> /usr/share/easy-rsa/vars
echo -en "export KEY_ORG=\042${company}\042\n" >> /usr/share/easy-rsa/vars
echo -en "export KEY_EMAIL=\042${email}042\n" >> /usr/share/easy-rsa/vars
echo -en "export KEY_CN=\042${company}\042\n" >> /usr/share/easy-rsa/vars
echo -en "export KEY_OU=\042IT\042\n" >> /usr/share/easy-rsa/vars
echo -en "#export KEY_NAME=\042servername\042\n" >> /usr/share/easy-rsa/vars
echo -en "#export KEY_ALTNAMES=\042altservername\042\n" >> /usr/share/easy-rsa/vars

#Генерируем сертификаты
cd $EASYRSAPATH
. ./vars
./easyrsa init-pki
# Создаём корневой сертификат
#(echo -en "\n\n") | ./easyrsa build-ca nopass # без пароля стрёмно чот
./easyrsa build-ca
# Создаём ключ Диффи-Хэлмана
./easyrsa gen-dh
# Создаём запрос на сертификат для сервера и сам сертификат
(echo -en "\n") | ./easyrsa gen-req $company nopass
#(echo -en "yes"; sleep 1; echo -en "\n") | ./easyrsa sign-req server $company
./easyrsa sign-req server $company
# Создаём ta-ключ
openvpn --genkey --secret pki/$company-ta.key

# Создаём запрос на клиентский сертификат и сам сертификат
(echo -en "\n") | ./easyrsa gen-req $company-user nopass
./easyrsa sign-req client $company-user

# Копируем ключи в общую папку
cp pki/ca.crt pki/$company-ca.crt
mkdir $KEYSPATH
cp -r pki/* $KEYSPATH

# Сортируем серверные и клиентские ключи
mkdir $CLIENTPATH
cd $KEYSPATH
cp *ca.crt issued/$company.crt private/$company.key dh.pem *ta.key $SERVERPATH
cp *ca.crt issued/*user.crt private/*user.key dh.pem *ta.key $CLIENTPATH

# Создаём /ccd и server.conf
mkdir /etc/openvpn/ccd
touch /etc/openvpn/ccd/$company-user
#указываем СВОИ подсети
echo -en "ifconfig-push 10.1.$tun.4 10.1.$tun.1\niroute 10.1.1.0 255.255.255.0\niroute 192.168.102.0 255.255.255.0\n" >> /etc/openvpn/ccd/$company-user

touch /etc/openvpn/server.conf
echo -en "port 1194\nproto $protocol\ndev tun0\nca /etc/openvpn/server/$company-ca.crt\n" >> /etc/openvpn/server.conf
echo -en "cert $company-server.crt\nkey $company-server.key\ndh dh2048.pem\n" >> /etc/openvpn/server.conf
echo -en "server 10.1.$tun.0 255.255.255.0\nclient-config-dir ccd\nroute 10.1.1.0 255.255.255.0\n" >> /etc/openvpn/server.conf
echo -en "route 10.1.$tun.0 255.255.255.0\nroute 192.168.102.0 255.255.255.0 10.1.$tun.2\n" >> /etc/openvpn/server.conf
echo -en "#push \042redirect-gateway def1\042\nkeepalive 10 120\ntls-auth $company-ta.key 0\n" >> /etc/openvpn/server.conf
echo -en "cipher DES-EDE3-CBC\ncomp-lzo\npersist-key\npersist-tun\n" >> /etc/openvpn/server.conf
echo -en "status openvpn-status.log\nlog /var/log/openvpn.log\nverb 3\n" >> /etc/openvpn/server.conf


# ****Генерация rc.local и iptables.rules ************************
#rm /etc/rc.local
#touch /etc/rc.local
#chmod 755 /etc/rc.local
#echo -en "#!/bin/sh -e\niptables-restore < /etc/iptables.rules\nexit 0\n" >> /etc/rc.local
#touch /etc/iptables.rules
#echo -en "*mangle\n:PREROUTING ACCEPT [44213:4111894]\n:INPUT ACCEPT [22109:2121408]\n:FORWARD ACCEPT [0:0]\n:OUTPUT ACCEPT [222:25744]\n:POSTROUTING ACCEPT [222:25744]\nCOMMIT\n" >> /etc/iptables.rules
#echo -en "*filter\n:INPUT DROP [21121:2005015]\n:FORWARD ACCEPT [0:0]\n:OUTPUT ACCEPT [222:25744]\n" >> /etc/iptables.rules
#echo -en "-A INPUT -i tun0 -j ACCEPT\n-A INPUT -i lo -j ACCEPT\n-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT\n-A INPUT -p tcp -m tcp --dport $ssh -j ACCEPT\n" >> /etc/iptables.rules
#echo -en "-A INPUT -p $protocol -m $protocol --dport 1194 -j ACCEPT\n" >> /etc/iptables.rules
#echo -en "-A INPUT -s 185.45.152.174/32 -p udp -m udp --dport 5060 -j ACCEPT\n-A INPUT -s 178.16.26.122/32 -p udp -m udp --dport 5060 -j ACCEPT\n-A INPUT -s 176.9.145.115/32 -p udp -m udp --dport 5060 -j ACCEPT\n" >> /etc/iptables.rules
#echo -en "-A INPUT -s 5.9.108.25/32 -p udp -m udp --dport 5060 -j ACCEPT\n-A INPUT -s 89.249.23.194/32 -p udp -m udp --dport 5060 -j ACCEPT\n-A INPUT -s 195.122.19.17/32 -p udp -m udp --dport 5060 -j ACCEPT\n" >> /etc/iptables.rules
#echo -en "-A INPUT -s 195.122.19.18/32 -p udp -m udp --dport 5060 -j ACCEPT\n-A INPUT -s 195.122.19.19/32 -p udp -m udp --dport 5060 -j ACCEPT\n-A INPUT -s 195.122.19.9/32 -p udp -m udp --dport 5060 -j ACCEPT\n" >> /etc/iptables.rules
#echo -en "-A INPUT -s 195.122.19.10/32 -p udp -m udp --dport 5060 -j ACCEPT\n-A INPUT -s 195.122.19.11/32 -p udp -m udp --dport 5060 -j ACCEPT\n-A INPUT -s 91.228.238.172/32 -p udp -m udp --dport 5060 -j ACCEPT\n" >> /etc/iptables.rules
#echo -en "-A INPUT -s 185.45.152.128/28 -p udp -m udp --dport 5060 -j ACCEPT\n-A INPUT -s 185.45.152.160/27 -p udp -m udp --dport 5060 -j ACCEPT\n" >> /etc/iptables.rules
#echo -en "-A INPUT -p udp -m udp --dport 10000:20000 -j ACCEPT\n-A INPUT -p icmp -m icmp --icmp-type 0 -j ACCEPT\n-A INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT\n" >> /etc/iptables.rules
#echo -en "COMMIT\n##############\n*nat\n:PREROUTING ACCEPT [8279:852947]\n:OUTPUT ACCEPT [0:0]\n:POSTROUTING ACCEPT [0:0]\n" >> /etc/iptables.rules
#echo -en "-A POSTROUTING -o $net -j SNAT --to-source $vdsip\nCOMMIT\n*raw\n:PREROUTING ACCEPT [44288:4119009]\n:OUTPUT ACCEPT [222:25744]\nCOMMIT\n" >> /etc/iptables.rules
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
#touch /etc/openvpn/user/$company-openvpn.log #должен быть пустой
#touch /etc/openvpn/user/$company-user.ovpn
#echo -en "client\ndev tun$tun\nproto $protocol\nremote $vdsip 1194\nresolv-retry infinite\nnobind\npersist-key\npersist-tun\n" >> /etc/openvpn/user/$company-user.ovpn
#echo -en "ca /etc/openvpn/$company/$company-ca.crt\ncert /etc/openvpn/$company/$company-user.crt\nkey /etc/openvpn/$company/$company-user.key\ntls-auth /etc/openvpn/$company/$company-ta.key 1\ncipher DES-EDE3-CBC\n" >> /etc/openvpn/user/$company-user.ovpn
#echo -en "ns-cert-type server\ncomp-lzo\nlog /etc/openvpn/$company/$company-openvpn.log\nverb 3\nscript-security 2\nup \042/etc/openvpn/$company/$company-up.sh\042\n" >> /etc/openvpn/user/$company-user.ovpn
#touch /etc/openvpn/user/$company-up.sh
#echo -en "#!/bin/bash\n/sbin/ip route add default via 10.1.$tun.1 dev tun$tun table $company\n" >> /etc/openvpn/user/$company-up.sh
#echo -en "#/sbin/ip rule add from 10.1.1.x table $company #KB\n#/sbin/ip rule add from 192.168.x.x table $company #TXM\n" >> /etc/openvpn/user/$company-up.sh
#echo -en "/sbin/ip route flush cache\n" >> /etc/openvpn/user/$company-up.sh
#cd $CAUSERPATH
#ln -s $company-user.ovpn $company-user.conf
#tar -cvf $company.tar *
echo
echo "Клиентские сертификаты и конфиги сгенерированы (8 файлов) и упакованы в архив /etc/openvpn/user/$company.tar. Его нужно скопировать на шлюз."
# ****************************************************************
echo
echo -e "***** Script \033[33;1m3\033[0m of \033[33;1m3\033[0m COMPLETED in $SECONDS seconds *****"
echo
