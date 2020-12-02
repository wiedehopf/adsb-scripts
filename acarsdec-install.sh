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

adduser --system --home $ipath --no-create-home --quiet acarsdec
adduser acarsdec plugdev

GIT=/tmp/acarsdec-build
rm -rf $GIT
git clone --depth 1 https://github.com/TLeconte/acarsdec.git $GIT
cd $GIT

mkdir build
cd build
cmake .. -Drtl=ON
make -j2

cp acarsdec /usr/local/bin

systemctl enable acarsdec
systemctl restart acarsdec
