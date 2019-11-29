#!/bin/bash
# Подготавливаем машину для работы.
SECONDS=0
printf "\033c"
#Проверяем подключение модулей ядра tun/tap
if [ -c /dev/net/tun ]; then
    echo -e "\e[1;32mTUN/TAP включены.\e[0m"
else
    echo -e "\e[31mTUN/TAP отключены. Надо включить, чтобы использовать эти скрипты.\e[0m"
    exit 1
fi
#Проверяем учётную запись
IAM=$(whoami)
if [ ${IAM} != "root" ]; then
    echo -e "\e[31mВам надо зайти под рутом, чтобы использовать эти скрипты.\e[0m"
    exit 1
fi
# Очистка файла motd
mv /etc/motd /etc/motd.bak
touch /etc/motd && chmod 664 /etc/motd

# Настройка ssh
## Можно выбрать один из предложенных блоков с настройками ssh.

#### 1. Это блок по умолчанию для локальной машины. Закомментируйте этот блок 1, и расскомментируйте блок 2,если хотите подключаться к серверу по ключу.
# Генерация файла sshd_config для доступа по ssh-ключу
mv /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
touch /etc/ssh/sshd_config
echo -en "Port 22\nAddressFamily inet\nProtocol 2\nDebianBanner no\nPrintMotd no\n" >> /etc/ssh/sshd_config
echo -en "SyslogFacility AUTH\nLogLevel VERBOSE\nLoginGraceTime 15\nStrictModes yes\n" >> /etc/ssh/sshd_config
echo -en "PrintLastLog yes\nKexAlgorithms diffie-hellman-group14-sha1\nHostKey /etc/ssh/ssh_host_rsa_key\n" >> /etc/ssh/sshd_config
echo -en "HostKey /etc/ssh/ssh_host_dsa_key\nHostKey /etc/ssh/ssh_host_ecdsa_key\n" >> /etc/ssh/sshd_config
echo -en "HostKey /etc/ssh/ssh_host_ed25519_key\nIgnoreRhosts yes\nPermitEmptyPasswords no\n" >> /etc/ssh/sshd_config
echo -en "PermitRootLogin yes\nHostbasedAuthentication no\nChallengeResponseAuthentication no\n" >> /etc/ssh/sshd_config
echo -en "KerberosAuthentication no\nGSSAPIAuthentication no\nGSSAPICleanupCredentials yes\n" >> /etc/ssh/sshd_config
echo -en "UsePAM yes\nX11DisplayOffset 10\nX11Forwarding yes\nX11UseLocalhost no\n" >> /etc/ssh/sshd_config
echo -en "TCPKeepAlive yes\nUsePrivilegeSeparation yes\nPermitUserEnvironment no\n" >> /etc/ssh/sshd_config
echo -en "ClientAliveCountMax 0\nUseDNS no\nMaxStartups 10:50:30\n" >> /etc/ssh/sshd_config
echo -en "AcceptEnv LANG LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES\n" >> /etc/ssh/sshd_config
echo -en "AcceptEnv LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT\n" >> /etc/ssh/sshd_config
echo -en "AcceptEnv LC_IDENTIFICATION LC_ALL LANGUAGE\nAcceptEnv XMODIFIERS\n" >> /etc/ssh/sshd_config
echo -en "Subsystem sftp /usr/lib/openssh/sftp-server\nCompression no\nMACs hmac-sha2-256\n" >> /etc/ssh/sshd_config
chmod 644 /etc/ssh/sshd_config
####

#### 2. Раскомментируйте этот блок, если хотите подключаться к серверу по ключу
# Генерация файла sshd_config для доступа по ssh-ключу
#mkdir /root/.ssh
#mv /root/authorized_keys /root/.ssh
#chmod 700 /root/.ssh
#chmod 600 /root/.ssh/authorized_keys
#mv /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
#touch /etc/ssh/sshd_config
#echo -en "Port 22\nAddressFamily inet\nProtocol 2\nDebianBanner no\nPrintMotd no\n" >> /etc/ssh/sshd_config
#echo -en "SyslogFacility AUTH\nLogLevel VERBOSE\nLoginGraceTime 15\nStrictModes yes\n" >> /etc/ssh/sshd_config
#echo -en "PrintLastLog yes\nKexAlgorithms diffie-hellman-group14-sha1\nHostKey /etc/ssh/ssh_host_rsa_key\n" >> /etc/ssh/sshd_config
#echo -en "HostKey /etc/ssh/ssh_host_dsa_key\nHostKey /etc/ssh/ssh_host_ecdsa_key\n" >> /etc/ssh/sshd_config
#echo -en "HostKey /etc/ssh/ssh_host_ed25519_key\nPubkeyAuthentication yes\n" >> /etc/ssh/sshd_config
#echo -en "AuthorizedKeysFile %h/.ssh/authorized_keys\nIgnoreRhosts yes\n" >> /etc/ssh/sshd_config
#echo -en "PermitEmptyPasswords no\nHostbasedAuthentication no\nChallengeResponseAuthentication no\n" >> /etc/ssh/sshd_config
#echo -en "KerberosAuthentication no\nGSSAPIAuthentication no\nGSSAPICleanupCredentials yes\n" >> /etc/ssh/sshd_config
#echo -en "UsePAM yes\nX11DisplayOffset 10\nX11Forwarding yes\nX11UseLocalhost no\nTCPKeepAlive yes\n" >> /etc/ssh/sshd_config
#echo -en "UsePrivilegeSeparation yes\nPermitUserEnvironment no\nClientAliveCountMax 0\n" >> /etc/ssh/sshd_config
#echo -en "UseDNS no\nMaxStartups 10:50:30\n" >> /etc/ssh/sshd_config
#echo -en "AcceptEnv LANG LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES\n" >> /etc/ssh/sshd_config
#echo -en "AcceptEnv LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT\n" >> /etc/ssh/sshd_config
#echo -en "AcceptEnv LC_IDENTIFICATION LC_ALL LANGUAGE\nAcceptEnv XMODIFIERS\n" >> /etc/ssh/sshd_config
#echo -en "Subsystem sftp /usr/lib/openssh/sftp-server\nCompression no\nMACs hmac-sha2-256\n" >> /etc/ssh/sshd_config
#chmod 644 /etc/ssh/sshd_config
####

# Скачиваем скрипты и даём права на запуск
#wget https://raw.githubusercontent.com/Krushon/VPN_scripts/master/openvpn-server-script/0_script-prepare.sh
wget https://raw.githubusercontent.com/Krushon/VPN_scripts/master/openvpn-server-script/1_script-upgrade.sh
wget https://raw.githubusercontent.com/Krushon/VPN_scripts/master/openvpn-server-script/2_script-install.sh
wget https://raw.githubusercontent.com/Krushon/VPN_scripts/master/openvpn-server-script/3_script-cert.sh
wget https://raw.githubusercontent.com/Krushon/VPN_scripts/master/openvpn-server-script/add-vpn-user
wget https://raw.githubusercontent.com/Krushon/VPN_scripts/master/openvpn-server-script/del-vpn-user
chmod +x 1_script-upgrade.sh 2_script-install.sh 3_script-cert.sh add-vpn-user del-vpn-user
echo
echo -e "***** Script \033[33;1m0\033[0m of \033[33;1m3\033[0m COMPLETED in $SECONDS seconds *****"
echo
