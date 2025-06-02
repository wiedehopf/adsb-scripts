#!/bin/bash
umask 022

apt update
apt install -y perl wget

# remove fr24feed in package form
apt purge -y fr24feed
# remove the fr24feed updater (should be removed with the package but let's make real sure)
rm -f /etc/cron.d/fr24feed_updater

set -e

if ! id -u fr24 &>/dev/null; then
    adduser --system --no-create-home fr24 || true
    addgroup fr24 || true
    adduser fr24 fr24 || true
fi
cd
rm /tmp/fr24 -rf
mkdir -p /tmp/fr24
cd /tmp

wget -O fr24.deb https://repo-feed.flightradar24.com/rpi_binaries/fr24feed_1.0.51-0_armhf.deb

dpkg -x fr24.deb fr24
cp -f fr24/usr/bin/fr24feed* /usr/bin

if ! [[ -f /etc/fr24feed.ini ]]; then
    cat >/etc/fr24feed.ini << "EOF"
bs=no
raw=no
mlat="no"
mlat-without-gps="no"
EOF
fi

chmod 666 /etc/fr24feed.ini


wget -O /etc/systemd/system/fr24feed.service https://raw.githubusercontent.com/wiedehopf/adsb-scripts/master/fr24feed.service
systemctl enable fr24feed


echo ----------------------------
echo fr24feed installed / updated!
echo ----------------------------
