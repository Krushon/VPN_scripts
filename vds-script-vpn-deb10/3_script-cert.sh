#!/bin/bash
# Генерируем необходимые сертификаты для VPN.
SECONDS=0
printf "\033c"

EASYRSAPATH=/usr/share/easy-rsa/
KEYSPATH=/etc/openvpn/keys/
USERPATH=/etc/openvpn/user/
SERVERPATH=/etc/openvpn/server/

# Уточняем необходииые данные
echo "Certificate issue..."
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

# Получаем имя сетевого интерфейса (eth0, ens32, eno1 и т.д.)
net=`ip r | grep default | grep -Po '(?<=dev )(\S+)'`
# Получаем ip-адрес сетевого интерфейса $net
vdsip=`ip addr show $net | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}'`

# Разносим полученные данные по конфигам
sed -i "1s/22/${ssh}/" /etc/ssh/sshd_config

touch /usr/share/easy-rsa/vars
echo -en "export KEY_COUNTRY=\042RU\042\n" >> /usr/share/easy-rsa/vars
echo -en "export KEY_PROVINCE=\042MSK\042\n" >> /usr/share/easy-rsa/vars
echo -en "export KEY_CITY=\042Moscow\042\n" >> /usr/share/easy-rsa/vars
echo -en "export KEY_ORG=\042${company}\042\n" >> /usr/share/easy-rsa/vars
echo -en "export KEY_EMAIL=\042${email}\042\n" >> /usr/share/easy-rsa/vars
echo -en "export KEY_CN=\042${company}\042\n" >> /usr/share/easy-rsa/vars
echo -en "export KEY_OU=\042IT\042\n" >> /usr/share/easy-rsa/vars
echo -en "#export KEY_NAME=\042servername\042\n" >> /usr/share/easy-rsa/vars
echo -en "#export KEY_ALTNAMES=\042altservername\042\n" >> /usr/share/easy-rsa/vars

### Генерируем сертификаты
cd $EASYRSAPATH
. ./vars
./easyrsa init-pki
# Создаём корневой сертификат
(echo -en "\n\n") | ./easyrsa build-ca nopass # без пароля
./easyrsa build-ca
# Создаём ключ Диффи-Хэлмана
./easyrsa gen-dh
# Создаём запрос на сертификат для сервера и сам сертификат
(echo -en "\n") | ./easyrsa gen-req $company nopass
(sleep 1; echo -en "yes\n"; sleep 1; echo -en "\n") | ./easyrsa sign-req server $company nopass
# Создаём ta-ключ
openvpn --genkey --secret pki/$company-ta.key
# Создаём запрос на клиентский сертификат и сам сертификат
(echo -en "\n") | ./easyrsa gen-req $company-user nopass
(sleep 1; echo -en "yes\n"; sleep 1; echo -en "\n") | ./easyrsa sign-req client $company-user nopass

# Копируем ключи в общую папку
cp pki/ca.crt pki/$company-ca.crt
mkdir $KEYSPATH
cp -r pki/* $KEYSPATH

# Сортируем серверные и пользовательские ключи
mkdir $USERPATH
cd $KEYSPATH
cp *ca.crt issued/$company.crt private/$company.key dh.pem *ta.key $SERVERPATH
cp *ca.crt issued/*user.crt private/*user.key dh.pem *ta.key $USERPATH

# Создаём /ccd и server.conf
mkdir /etc/openvpn/ccd
touch /etc/openvpn/ccd/$company-user
#!!! указываем СВОИ подсети !!!
echo -en "ifconfig-push 10.1.$tun.4 10.1.$tun.1\niroute 10.1.1.0 255.255.255.0\niroute 192.168.102.0 255.255.255.0\n" >> /etc/openvpn/ccd/$company-user
touch /etc/openvpn/server.conf
echo -en "port 1194\nproto $protocol\ndev tun0\nca /etc/openvpn/server/$company-ca.crt\n" >> /etc/openvpn/server.conf
echo -en "cert $company-server.crt\nkey $company-server.key\ndh dh2048.pem\n" >> /etc/openvpn/server.conf
echo -en "server 10.1.$tun.0 255.255.255.0\nclient-config-dir ccd\nroute 10.1.1.0 255.255.255.0\n" >> /etc/openvpn/server.conf
echo -en "route 10.1.$tun.0 255.255.255.0\nroute 192.168.102.0 255.255.255.0 10.1.$tun.2\n" >> /etc/openvpn/server.conf
echo -en "#push \042redirect-gateway def1\042\nkeepalive 10 120\ntls-auth $company-ta.key 0\n" >> /etc/openvpn/server.conf
echo -en "cipher DES-EDE3-CBC\ncomp-lzo\npersist-key\npersist-tun\n" >> /etc/openvpn/server.conf
echo -en "status openvpn-status.log\nlog /var/log/openvpn.log\nverb 3\n" >> /etc/openvpn/server.conf

# **** Настраиваем файрвол ***************************************
systemctl enable nftables
touch ~/ruleset.nft
echo -en "add table ip mangle\n" >> ~/ruleset.nft
echo -en "add chain ip mangle PREROUTING { type filter hook prerouting priority -150; policy accept; }\n" >> ~/ruleset.nft
echo -en "add chain ip mangle INPUT { type filter hook input priority -150; policy accept; }\n" >> ~/ruleset.nft
echo -en "add chain ip mangle FORWARD { type filter hook forward priority -150; policy accept; }\n" >> ~/ruleset.nft
echo -en "add chain ip mangle OUTPUT { type route hook output priority -150; policy accept; }\n" >> ~/ruleset.nft
echo -en "add chain ip mangle POSTROUTING { type filter hook postrouting priority -150; policy accept; }\n" >> ~/ruleset.nft
echo -en "add table ip filter\n" >> ~/ruleset.nft
echo -en "add chain ip filter INPUT { type filter hook input priority 0; policy drop; }\n" >> ~/ruleset.nft
echo -en "add chain ip filter FORWARD { type filter hook forward priority 0; policy accept; }\n" >> ~/ruleset.nft
echo -en "add chain ip filter OUTPUT { type filter hook output priority 0; policy accept; }\n" >> ~/ruleset.nft
echo -en "add rule ip filter INPUT iifname "tun0" counter accept\n" >> ~/ruleset.nft
echo -en "add rule ip filter INPUT iifname "lo" counter accept\n" >> ~/ruleset.nft
echo -en "add rule ip filter INPUT ct state related,established  counter accept\n" >> ~/ruleset.nft
# открываем tcp-порт для подключения по ssh
echo -en "add rule ip filter INPUT tcp dport $ssh counter accept\n" >> ~/ruleset.nft
# открываем порт для подключения клиента openvpn
echo -en "add rule ip filter INPUT $protocol dport 1194 counter accept\n" >> ~/ruleset.nft
#--- добавляем ip-адреса sip-провайдеров ---#
# zadarma 
echo -en "add rule ip filter INPUT ip saddr 185.45.152.0/24 udp dport 5060 counter accept\n" >> ~/ruleset.nft
echo -en "add rule ip filter INPUT ip saddr 185.45.155.0/24 udp dport 5060 counter accept\n" >> ~/ruleset.nft
echo -en "add rule ip filter INPUT ip saddr 37.139.38.0/24 udp dport 5060 counter accept\n" >> ~/ruleset.nft
echo -en "add rule ip filter INPUT ip saddr 195.122.19.0/27 udp dport 5060 counter accept\n" >> ~/ruleset.nft
# gobaza
echo -en "add rule ip filter INPUT ip saddr 213.145.46.78 udp dport 5060 counter accept\n" >> ~/ruleset.nft
echo -en "add rule ip filter INPUT ip saddr 213.145.53.135 udp dport 5060 counter accept\n" >> ~/ruleset.nft
echo -en "add rule ip filter INPUT ip saddr 213.145.53.135 udp dport 10000-65000 counter accept\n" >> ~/ruleset.nft
echo -en "add rule ip filter INPUT ip saddr 213.145.53.128/27 udp dport 10000-65000 counter accept\n" >> ~/ruleset.nft
# mtt, youmagic
echo -en "add rule ip filter INPUT ip saddr 80.75.130.132 udp dport 5060 counter accept\n" >> ~/ruleset.nft
echo -en "add rule ip filter INPUT ip saddr 80.75.130.136 udp dport 5060 counter accept\n" >> ~/ruleset.nft
echo -en "add rule ip filter INPUT ip saddr 80.75.128.30 udp dport 5060 counter accept\n" >> ~/ruleset.nft
echo -en "add rule ip filter INPUT ip saddr 80.75.132.66 udp dport 5060 counter accept\n" >> ~/ruleset.nft
# siplink
echo -en "add rule ip filter INPUT ip saddr 89.108.107.101 udp dport 5060 counter accept\n" >> ~/ruleset.nft
echo -en "add rule ip filter INPUT udp dport 9000-9999 counter accept\n" >> ~/ruleset.nft
# в диапазоне 10000:20000 генерируется случайный порт для sip-разговора
echo -en "add rule ip filter INPUT udp dport 10000-20000 counter accept\n" >> ~/ruleset.nft
#-------------------------------------------#
# оставляем возможность пинговать машину и пинговать с машины
echo -en "add rule ip filter INPUT icmp type echo-reply counter accept\n" >> ~/ruleset.nft
echo -en "add rule ip filter INPUT icmp type echo-request counter accept\n" >> ~/ruleset.nft
echo -en "add table ip nat\n" >> ~/ruleset.nft
echo -en "add chain ip nat PREROUTING { type nat hook prerouting priority -100; policy accept; }\n" >> ~/ruleset.nft
echo -en "add chain ip nat OUTPUT { type nat hook output priority -100; policy accept; }\n" >> ~/ruleset.nft
echo -en "add chain ip nat POSTROUTING { type nat hook postrouting priority 100; policy accept; }\n" >> ~/ruleset.nft
echo -en "add rule ip nat POSTROUTING oifname "$net" counter snat to $vdsip\n" >> ~/ruleset.nft
echo -en "add table ip raw\n" >> ~/ruleset.nft
echo -en "add chain ip raw PREROUTING { type filter hook prerouting priority -300; policy accept; }\n" >> ~/ruleset.nft
echo -en "add chain ip raw OUTPUT { type filter hook output priority -300; policy accept; }\n" >> ~/ruleset.nft
nft -f ~/ruleset.nft
echo '#!/usr/sbin/nft -f' > /etc/nftables.conf
echo 'flush ruleset' >> /etc/nftables.conf
nft list ruleset >> /etc/nftables.conf
# ****************************************************************

# Настраиваем fail2ban
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
cd $USERPATH
touch $company-openvpn.log #должен быть пустой
touch $company-user.ovpn
echo -en "client\ndev tun$tun\nproto $protocol\nremote $vdsip 1194\nresolv-retry infinite\nnobind\npersist-key\npersist-tun\n" >> /etc/openvpn/user/$company-user.ovpn
echo -en "ca /etc/openvpn/$company/$company-ca.crt\ncert /etc/openvpn/$company/$company-user.crt\nkey /etc/openvpn/$company/$company-user.key\ntls-auth /etc/openvpn/$company/$company-ta.key 1\ncipher DES-EDE3-CBC\n" >> /etc/openvpn/user/$company-user.ovpn
echo -en "ns-cert-type server\ncomp-lzo\nlog /etc/openvpn/$company/$company-openvpn.log\nverb 3\nscript-security 2\nup \042/etc/openvpn/$company/$company-up.sh\042\n" >> /etc/openvpn/user/$company-user.ovpn
touch $company-up.sh
echo -en "#!/bin/bash\n/sbin/ip route add default via 10.1.$tun.1 dev tun$tun table $company\n" >> /etc/openvpn/user/$company-up.sh
echo -en "#/sbin/ip rule add from 10.1.1.x table $company #KB\n#/sbin/ip rule add from 192.168.x.x table $company #TXM\n" >> /etc/openvpn/user/$company-up.sh
echo -en "/sbin/ip route flush cache\n" >> /etc/openvpn/user/$company-up.sh
ln -s $company-user.ovpn $company-user.conf
tar -cvf $company.tar *
echo
echo "Клиентские сертификаты и конфиги сгенерированы (8 файлов) и упакованы в архив /etc/openvpn/user/$company.tar. Его нужно скопировать на шлюз."
# ****************************************************************
echo
echo -e "***** Script \033[33;1m3\033[0m of \033[33;1m3\033[0m COMPLETED in $SECONDS seconds *****"
echo
