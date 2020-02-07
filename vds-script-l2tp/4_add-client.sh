#!/bin/bash
#
# !!! Скрипт недоделан и находится в проекте !!!
#
# Создание пользователя для авторизации
#
#
# НА ВЫБОР:
#
# 1-1. Можно использовать свой psk-ключ (CLIENTPASSOWRD):
# Для этого блок 1-1 должен быть раскомментирован, а блок 1-2 - закомментирован.
# ИЛИ
# 1-2. Можно использовать автоматическую генерацию 32х-символьного ключа:
# Для этого блок 1-1 должен быть закомментирован, а блок 1-2 - раскомментирован.
#
# 2-1. Можно вводить почту клиента (CLIENTEMAIL), для отправки ему psk-ключа:
# Для этого блок 2-1 должен быть раскомментирован, а блок 2-2 - закомментирован.
# ИЛИ
# 2-2. Можно указать почтоянную почту администратора для приёма новых ключей:
# Для этого блок 2-1 нужно закомментировать, блок 2-2 раскомментировать и внести нужную почту.


SECONDS=0
printf "\033c"

echo "Enter the new \"CLIENT\" "
read CLIENT

## Начало блока 1-1
echo "Enter the new \"CLIENTPASSWORD\" "
read CLIENTPASSWORD
## Конец блока 1-1

## Начало блока 1-2
#CLIENTPASSWORD=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32};echo;`
## Конец блока 1-2

## Начало блока 2-1
echo "Enter the new \"CLIENTEMAIL\" "
read CLIENTEMAIL
## Конец блока 2-1

## Начало блока 2-2
#CLIENTEMAIL="email@email.com"
## Конец блока 2-2

echo -en "$CLIENT VPN $CLIENTPASSWORD *\n" >> /etc/ppp/chap-secrets

# Отправляем готовые psk-ключи на почту
echo "PSK-keys for $CLIENT: $CLIENTPASSWORD" | mutt -s "PSK-keys for $CLIENT" $CLIENTEMAIL

echo
echo "***** Script COMPLETED in $SECONDS seconds *****"
echo
