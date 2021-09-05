#!/bin/bash

sudo apt update
sudo apt install -y perl wget
sudo apt remove -y fr24feed

set -e

sudo adduser --system --no-create-home fr24 || true
cd
rm /tmp/fr24 -rf
mkdir -p /tmp/fr24
cd /tmp

wget -O fr24.deb https://repo-feed.flightradar24.com/rpi_binaries/fr24feed_1.0.28-1_armhf.deb

dpkg -x fr24.deb fr24
cp -f fr24/usr/bin/fr24feed* /usr/bin
wget -O /etc/systemd/system/fr24feed.service https://raw.githubusercontent.com/wiedehopf/adsb-scripts/master/fr24feed.service
systemctl enable fr24feed


echo ----------------------------
echo fr24feed installed / updated!
echo ----------------------------
