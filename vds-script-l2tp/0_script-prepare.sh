#!/bin/bash
# Подготавливаем vds-машину для работы.
SECONDS=0
printf "\033c"

#Проверяем учётную запись
IAM=$(whoami)
if [ ${IAM} != "root" ]; then
    echo -e "\e[31mВам надо зайти под рутом, чтобы использовать эти скрипты.\e[0m"
    exit 1
fi

#Проверяем подключение модулей ядра tun/tap
if [ -c /dev/net/tun ]; then
    echo -e "\e[1;32mTUN/TAP включены.\e[0m"
else
    echo -e "\e[31mTUN/TAP отключено. Обратитесь к вашему провайдеру VPS/VDS, чтобы включить.\e[0m"
    exit 1
fi

lsmodafkey=`lsmod | grep af_key`
lsmodesp4=`lsmod | grep esp4`
lsmodxfrm4=`lsmod | grep xfrm4_mode_tunnel`
findmodafkey=`find /lib/modules -name *.ko | grep af_key | awk -F/ 'print $8}'`
findmodesp4=`find /lib/modules -name *.ko | grep esp4 | awk -F/ '{print $8}'` 
findmodxfrm4=`find /lib/modules -name *.ko | grep xfrm4_mode_tunnel | awk -F/ '{print $8}'`

#Проверяем подключение модуля ядра af_key
if [[ -n $lsmodafkey ]]
	then
		echo -e "\e[1;32mМодуль af_key включен.\e[0m"
elif [[ -z $lsmodafkey ]] && [[ -n $findmodafkey ]]
	then
		echo -e "\e[1;33mМодуль af_key установлен, но не включен. Включить его (Y/n)?\e[0m"
			read answer1
			case "$answer1" in
				y|Y) modprobe af_key
				echo -e "\e[1;32mМодуль af_key включен.\e[0m"
				;;
				n|N) echo -e "\e[1;31mОтмена. Модуль af_key не включен.\e[0m"
				exit 1
				;;
				*) echo "Ничего не ввели. Выполняется действие по умолчанию - включение модуля."
				modprobe af_key
				echo -e "\e[1;32mМодуль af_key включен.\e[0m"
				;;
			esac
else
    echo -e "\e[1;31mМодуль af_key не загружен.\e[0m"
    exit 1
fi

#Проверяем подключение модуля ядра esp4
if [[ -n $lsmodesp4 ]]
	then
		echo -e "\e[1;32mМодуль esp4 включен.\e[0m"
elif [[ -z $lsmodesp4 ]] && [[ -n $findmodesp4 ]]
	then
		echo -e "\e[1;33mМодуль esp4 установлен, но не включен. Включить его (Y/n)?\e[0m"
			read answer2
			case "$answer2" in
				y|Y) modprobe esp4
				echo -e "\e[1;32mМодуль esp4 включен.\e[0m"
				;;
				n|N) echo -e "\e[1;31mОтмена. Модуль esp4 не включен.\e[0m"
				exit 1
				;;
				*) echo "Ничего не ввели. Выполняется действие по умолчанию - включение модуля."
				modprobe esp4
				echo -e "\e[1;32mМодуль esp4 включен.\e[0m"
				;;
			esac
else
    echo -e "\e[1;31mМодуль esp4 не загружен.\e[0m"
    exit 1
fi

#Проверяем подключение модуля ядра xfrm4_mode_tunnel
if [[ -n $lsmodxfrm4 ]]
	then
		echo -e "\e[1;32mМодуль xfrm4_mode_tunnel включен.\e[0m"
elif [[ -z $lsmodxfrm4 ]] && [[ -n $findmodxfrm4 ]]
	then
		echo -e "\e[1;33mМодуль xfrm4_mode_tunnel установлен, но не включен. Включить его (Y/n)?\e[0m"
			read answer3
			case "$answer3" in
				y|Y) modprobe xfrm4_mode_tunnel
				echo -e "\e[1;32mМодуль xfrm4_mode_tunnel включен.\e[0m"
				;;
				n|N) echo -e "\e[1;31mОтмена. Модуль xfrm4_mode_tunnel не включен.\e[0m"
				exit 1
				;;
				*) echo "Ничего не ввели. Выполняется действие по умолчанию - включение модуля."
				modprobe xfrm4_mode_tunnel
				echo -e "\e[1;32mМодуль xfrm4_mode_tunnel включен.\e[0m"
				;;
			esac
else
    echo -e "\e[1;31mМодуль xfrm4_mode_tunnel не загружен.\e[0m"
    exit 1
fi

# Очистка файла motd
mv /etc/motd /etc/motd.bak
touch /etc/motd && chmod 664 /etc/motd
# Копирование ssh-ключа.
mkdir /root/.ssh
mv /root/authorized_keys /root/.ssh
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys
### Генерация файла sshd_config для доступа по ssh-ключу
mv /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
touch /etc/ssh/sshd_config
echo -en "Port 22\nAddressFamily inet\nProtocol 2\nDebianBanner no\nPrintMotd no\n" >> /etc/ssh/sshd_config
echo -en "SyslogFacility AUTH\nLogLevel VERBOSE\nLoginGraceTime 15\nStrictModes yes\n" >> /etc/ssh/sshd_config
echo -en "PrintLastLog yes\nKexAlgorithms diffie-hellman-group14-sha1\n" >> /etc/ssh/sshd_config
echo -en "HostKey /etc/ssh/ssh_host_rsa_key\nHostKey /etc/ssh/ssh_host_dsa_key\n" >> /etc/ssh/sshd_config
echo -en "HostKey /etc/ssh/ssh_host_ecdsa_key\nHostKey /etc/ssh/ssh_host_ed25519_key\n" >> /etc/ssh/sshd_config
echo -en "PubkeyAuthentication yes\nAuthorizedKeysFile %h/.ssh/authorized_keys\n" >> /etc/ssh/sshd_config
echo -en "IgnoreRhosts yes\nPermitEmptyPasswords no\nHostbasedAuthentication no\n" >> /etc/ssh/sshd_config
echo -en "ChallengeResponseAuthentication no\nKerberosAuthentication no\n" >> /etc/ssh/sshd_config
echo -en "GSSAPIAuthentication no\nGSSAPICleanupCredentials yes\nUsePAM yes\n" >> /etc/ssh/sshd_config
echo -en "X11DisplayOffset 10\nX11Forwarding yes\nX11UseLocalhost no\nTCPKeepAlive yes\n" >> /etc/ssh/sshd_config
echo -en "UsePrivilegeSeparation yes\nPermitUserEnvironment no\nClientAliveCountMax 0\n" >> /etc/ssh/sshd_config
echo -en "UseDNS no\nMaxStartups 10:50:30\n" >> /etc/ssh/sshd_config
echo -en "AcceptEnv LANG LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES\n" >> /etc/ssh/sshd_config
echo -en "AcceptEnv LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT\n" >> /etc/ssh/sshd_config
echo -en "AcceptEnv LC_IDENTIFICATION LC_ALL LANGUAGE\nAcceptEnv XMODIFIERS\n" >> /etc/ssh/sshd_config
echo -en "Subsystem sftp /usr/lib/openssh/sftp-server\nCompression no\nMACs hmac-sha2-256\n" >> /etc/ssh/sshd_config
chmod 644 /etc/ssh/sshd_config
###
#wget https://raw.githubusercontent.com/Krushon/VPN_scripts/master/vds-script-l2tp/0_script-prepare.sh
wget https://raw.githubusercontent.com/Krushon/VPN_scripts/master/vds-script-l2tp/1_script-upgrade.sh
wget https://raw.githubusercontent.com/Krushon/VPN_scripts/master/vds-script-l2tp/2_script-install.sh
wget https://raw.githubusercontent.com/Krushon/VPN_scripts/master/vds-script-l2tp/3_script-conf.sh
#wget https://raw.githubusercontent.com/Krushon/VPN_scripts/master/vds-script-l2tp/4_add-client.sh
#wget https://raw.githubusercontent.com/Krushon/VPN_scripts/master/vds-script-l2tp/5_del-client.sh
chmod +x 1_script-upgrade.sh 2_script-install.sh 3_script-conf.sh #4_add-client.sh 5_del-client.sh
echo
echo -e "***** Script \033[33;1m0\033[0m of \033[33;1m3\033[0m COMPLETED in $SECONDS seconds *****"
echo
