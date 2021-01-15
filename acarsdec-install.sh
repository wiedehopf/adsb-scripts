#!/bin/bash

set -e
repo="https://github.com/wiedehopf/adsb-scripts"
ipath=/usr/local/share/adsb-scripts
stuff="git libusb-1.0-0-dev librtlsdr-dev librtlsdr0"

apt install -y $stuff || apt update && apt install -y $stuff || true

mkdir -p $ipath
if git clone --depth 1 $repo $ipath/git 2>/dev/null || cd $ipath/git
then
	cd $ipath/git
	git checkout -f master
	git fetch
	git reset --hard origin/master
else
	echo "Download failed"
	exit 1
fi
cp acarsdec.service /lib/systemd/system
cp acarsdec.default /etc/default/acarsdec

sed -i -e "s/UNKNOWN/$RANDOM$RANDOM/" /etc/default/acarsdec

# blacklist kernel driver as on ancient systems
if grep -E 'wheezy|jessie' /etc/os-release -qs; then
    echo -e 'blacklist rtl2832\nblacklist dvb_usb_rtl28xxu\nblacklist rtl8192cu\nblacklist rtl8xxxu\n' > /etc/modprobe.d/blacklist-rtl-sdr.conf
    rmmod rtl2832 &>/dev/null
    rmmod dvb_usb_rtl28xxu &>/dev/null
    rmmod rtl8xxxu &>/dev/null
    rmmod rtl8192cu &>/dev/null
fi

adduser --system --home $ipath --no-create-home --quiet acarsdec
adduser acarsdec plugdev

GIT=/tmp/acarsdec-build
rm -rf $GIT
git clone --depth 1 https://github.com/airframesio/acarsdec.git $GIT
cd $GIT

mkdir build
cd build
cmake .. -Drtl=ON
make -j2

BIN=/usr/local/bin/acarsdec
rm -f $BIN
cp -T acarsdec $BIN

systemctl enable acarsdec
systemctl restart acarsdec

cd
rm -rf "$GIT"
