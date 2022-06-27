#!/bin/bash
# Checking the debian distribution version. Проверяем версию дистрибутива debian.
SECONDS=0
printf "\033c"
ver=`cat /etc/*-release | grep VERSION_ID | awk -F= '{print $2}'`
#  If the version is 8 then update to 11. Если версия 8, то обновляем до 11.
if [ $ver = '"8"' ]
  then
    echo "OS version is 8. Upgrading to 11..."
    cp /etc/apt/sources.list /etc/apt/sources.list_backup
    sed -i 's/jessie/bullseye/g' /etc/apt/sources.list
    apt-get update
    apt-get upgrade -y
    apt-get dist-upgrade -y
    apt autoremove -y
#  If 9 then update to 11. Если версия 9, то обновляем до 11.
elif [ $ver = '"9"' ]
  then
    echo "OS version is 9. Upgrading to 11..."
    cp /etc/apt/sources.list /etc/apt/sources.list_backup
    sed -i 's/stretch/bullseye/g' /etc/apt/sources.list
    apt-get update
    apt-get upgrade -y
    apt-get dist-upgrade -y
    apt autoremove -y
#  If 10 then update to 11. Если версия 10, то обновляем до 11.
elif [ $ver = '"10"' ]
  then
    echo "OS version is 10. Upgrading to 11..."
    cp /etc/apt/sources.list /etc/apt/sources.list_backup
    sed -i 's/buster/bullseye/g' /etc/apt/sources.list
    apt-get update
    apt-get upgrade -y
    apt-get dist-upgrade -y
    apt autoremove -y
#  If 11 then update. Если версия 11, то просто всё обновляем.
elif [ $ver = '"11"' ]
  then
    echo "Updating system..."
    apt-get update
    apt-get upgrade -y
    apt autoremove -y
# If version is not 8-11 then break. Если версия не 8, 9, 10, 11 и не debian, то скрипт завершается и потребуется ручное вмешательство.
  else
    echo -e "\e[31mSomething wnet wrong. Intervention is required.\e[0m"
    echo -e "\e[31mЧто-то пошло не так. Требуется вмешательство.\e[0m"
    exit 0
fi

# Check for a reboot recommendation after the update. Проверяем на рекомендацию перезагрузки после апдейта
reb=`cat /var/log/apt/term.log | grep Please | awk '{print $1, $2}'`
if [[ $reb == "Please reboot" ]]
  then
    echo -e "\e[1;31m### It would be nice to reboot if possible ###\e[0m"
    echo -e "\e[1;31m### Хорошо бы ребутнуться по возможности ###\e[0m"
fi

echo
echo -e "***** Script \033[33;1m1\033[0m of \033[33;1m3\033[0m COMPLETED in $SECONDS seconds *****"
echo