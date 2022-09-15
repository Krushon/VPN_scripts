#!/bin/bash
# Checking the debian distribution version. Проверяем версию дистрибутива debian.
SECONDS=0
printf "\033c"
ver=`cat /etc/*-release | grep VERSION_ID | awk -F= '{print $2}'`
# 8 - Support is over. Поддержка версии 8 (jessie) закончилась 30.06.2020.
# 9 - Support is over. Поддержка версии 9 (stretch) закончилась 30.06.2022.
# If 10 then update to 11. Если версия 10, то обновляем до 11.
if [ $ver = '"10"' ]
  then
    echo "OS version is 10. Upgrading to 11..."
    cp /etc/apt/sources.list /etc/apt/sources.list_backup
    sed -i 's/buster/bullseye/g' /etc/apt/sources.list
    apt update
    apt upgrade -y
    apt dist-upgrade -y
    apt autoremove -y
#  If 11 then update. Если версия 11, то просто всё обновляем.
elif [ $ver = '"11"' ]
  then
    echo "Updating system..."
    apt update
    apt upgrade -y
    apt autoremove -y
# If version is not 10,11 and debian then break. Если версия не 10, 11 и не debian, то скрипт завершается и потребуется ручное вмешательство.
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