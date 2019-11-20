#!/bin/bash
# Скрипт для копирования готовых сертификатов с vds на шлюз.
mkdir "$1"
#scp -i ключ root@"$1":/etc/openvpn/user/"$1".tar .
scp root@"$1":/etc/openvpn/user/"$1".tar .
mv "$1".tar ~/"$1"
tar -xvf ~/"$1"/"$1".tar -C ~/"$1"
