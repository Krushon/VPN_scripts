#!/bin/bash
#
# !!! Скрипт недоделан и находится в проекте !!!
#
# Создаём сертификат пользователя с указанием срока действия.
# Генерируем файл-скрипт на отправку уведомления пользователю о завершении срока действия сертификата.
SECONDS=0
printf "\033c"
EASYRSAPATH=/etc/openvpn/easy-rsa/
KEYSPATH=/etc/openvpn/easy-rsa/keys/

echo "Enter \"username\" "
read username
echo "Enter the certificate \"validity\" "
echo "example: 3650 = 10 years, 365 = 1 year, 30 = 1 month, 7 = 1 week, etc"
read validity
echo "Enter the username \"email\" "
read email

# Выписываем новый сертификат
cd $EASYRSAPATH
sed -i "60s/export KEY_EXPIRE=3650/export KEY_EXPIRE=${validity}/" /etc/openvpn/easy-rsa/vars
source vars
./clean-all
./build-key $username
cd $KEYSPATH
mkdir $username
cp ca.crt ta.key /etc/openvpn/easy-rsa/keys/$username/
cd $username
touch $username-3data.ovpn
echo -en "client\ndev tun\nremote 141.101.203.132 1194\nresolv-retry infinite\nnobind\npersist-key\n" >> $username-3data.ovpn
echo -en "persist-tun\nca ca.crt\ncert $username-user.crt\nkey $username-user.key\ntls-auth ta.key 1\ncipher DES-EDE3-CBC\n" >> $username-3data.ovpn
echo -en "ns-cert-type server\ncomp-lzo\nlog openvpn.log\nverb 3\n" >> $username-3data.ovpn
tar -zcf $username.tar.gz ca.crt ta.key *.ovpn *user.crt *user.key

# Отправляем готовые сертификаты на почту
echo "OpenVPN keys for $username" | mutt -s "OpenVPN keys for $username" $email -a $KEYSPATH/$username/$username.tar.gz

# Генерируем файл-скрипт, прописываем его на исполнение в cron





#sed -e "s/user/$1/" -e "s/$/`echo \\\r`/" umos-kms-t.ovpn > umos-kms.ovpn
#tar -zcf "$1".tar.gz ca.crt ta.key umos-kms.ovpn "$1".crt "$1".key
#echo "OpenVPN keys for user: $1" | mutt -s "OpenVPN keys for user: $1" $email -a $EASYRSAPATH/keys/"$1".tar.gz
#rm -f $EASYRSAPATH/keys/"$1".tar.gz $EASYRSAPATH/keys/umos-kms.ovpn


echo "***** Script COMPLETED in $SECONDS seconds *****"
echo
