#!/bin/bash
set -e
cd /tmp

repo="https://github.com/wiedehopf/adsb-scripts"
ipath=/usr/local/share/adsb-scripts
stuff="git cmake libusb-1.0-0-dev librtlsdr-dev librtlsdr0"
branch="testing"

if [[ -n $1 ]]; then
    branch="$1"
fi

apt install -y $stuff || apt update && apt install -y $stuff || true

mkdir -p $ipath

function gitUpdate() {
    _REPO="$1"
    _DIR="$2"
    _BRANCH="$3"
    { cd "$_DIR" &>/dev/null && git fetch --depth 1 origin "$_BRANCH" && git reset --hard origin/"$_BRANCH"; } ||
    { cd /tmp && rm -rf "$_DIR" && git clone --depth 1 --branch "$_BRANCH" "$_REPO" "$_DIR"; }

    if ! cd "$_DIR" || ! git rev-parse
    then
        echo "Unable to download files, exiting! (Maybe try again?)"
        exit 1
    fi
}

# get adsb-scripts repo
gitUpdate "$repo" "$ipath/git" master

cd acarsdec

cp service /lib/systemd/system/acarsdec.service
cp -n default /etc/default/acarsdec

sed -i -e "s/XX-YYYYZ/$RANDOM-$RANDOM/" /etc/default/acarsdec

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

GIT="$ipath/acarsdec-git"
gitUpdate https://github.com/airframesio/acarsdec.git "$GIT" "$branch"

rm -rf build
mkdir build
cd build
cmake .. -Drtl=ON
make -j2

BIN=/usr/local/bin/acarsdec
rm -f $BIN
cp -T acarsdec $BIN

systemctl enable acarsdec
systemctl restart acarsdec
