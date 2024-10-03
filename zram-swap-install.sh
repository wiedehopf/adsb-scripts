#!/bin/bash

set -e
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR

ipath=/usr/local/share/adsb-scripts/zram-swap/
rm -rf $ipath
mkdir -p $ipath
cd $ipath

wget -O $ipath/zram-swap.sh https://raw.githubusercontent.com/wiedehopf/adsb-scripts/master/zram-swap.sh
wget -O /lib/systemd/system/zram-swap.service https://raw.githubusercontent.com/wiedehopf/adsb-scripts/master/zram-swap.service

systemctl enable zram-swap
systemctl start zram-swap

echo "---------------------"
echo "zram-swap installed."
