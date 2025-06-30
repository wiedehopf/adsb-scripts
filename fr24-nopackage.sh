#!/bin/bash
umask 022

trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR

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

arch=$(dpkg --print-architecture)
if [[ $arch == amd64 ]] || [[ $arch == arm64 ]] || [[ $arch == i386 ]]; then
    wget -O fr24.deb https://repo-feed.flightradar24.com/rpi_binaries/fr24feed_1.0.51-0_${arch}.deb
else
    # fallback to armhf
    wget -O fr24.deb https://repo-feed.flightradar24.com/rpi_binaries/fr24feed_1.0.51-0_armhf.deb
fi

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

sed -i -e 's/^bs=.*/bs=no/' -e 's/^raw=.*/raw=no/' /etc/fr24feed.ini

chmod 666 /etc/fr24feed.ini


wget -O /etc/systemd/system/fr24feed.service https://raw.githubusercontent.com/wiedehopf/adsb-scripts/master/fr24feed.service
systemctl enable fr24feed


echo ----------------------------
echo fr24feed installed / updated!
echo ----------------------------
