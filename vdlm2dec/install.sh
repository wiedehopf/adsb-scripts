#!/bin/bash
umask 022
set -e
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd)/$(basename "$0")"
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR
renice 10 $$

cd /tmp

repo="https://github.com/wiedehopf/adsb-scripts"
ipath=/usr/local/share/adsb-scripts
stuff="git cmake libusb-1.0-0-dev librtlsdr-dev librtlsdr0 libairspy-dev"
branch="master"

if [[ -n $2 ]]; then
    branch="$2"
fi

apt install -y $stuff || apt update && apt install -y $stuff || true

mkdir -p $ipath

function getGIT() {
    # getGIT $REPO $BRANCH $TARGET (directory)
    if [[ -z "$1" ]] || [[ -z "$2" ]] || [[ -z "$3" ]]; then echo "getGIT wrong usage, check your script or tell the author!" 1>&2; return 1; fi
    REPO="$1"; BRANCH="$2"; TARGET="$3"; pushd .
    if cd "$TARGET" &>/dev/null && git fetch --depth 1 origin "$BRANCH" && git reset --hard FETCH_HEAD; then popd; return 0; fi
    if ! cd /tmp || ! rm -rf "$TARGET"; then popd; return 1; fi
    if git clone --depth 1 --single-branch --branch "$2" "$1" "$3"; then popd; return 0; fi
    popd; return 1;
}

# get adsb-scripts repo
getGIT "$repo" master "$ipath/git"

bash "$ipath/git/libacars/install.sh"

cd "$ipath/git/vdlm2dec"

cp service /lib/systemd/system/vdlm2dec.service
cp -n default /etc/default/vdlm2dec

if [[ $1 == "airspy" ]]; then
    sed -i -e 's/User=vdlm2dec/User=root/' /lib/systemd/system/vdlm2dec.service
    sed -i -e 's/^OPTIONS7=*/#\0/' /etc/default/vdlm2dec
fi

sed -i -e "s/XX-YYYYZ/$RANDOM-$RANDOM/" /etc/default/vdlm2dec

# blacklist kernel driver as on ancient systems
if grep -E 'wheezy|jessie' /etc/os-release -qs; then
    echo -e 'blacklist rtl2832\nblacklist dvb_usb_rtl28xxu\n' > /etc/modprobe.d/blacklist-rtl-sdr.conf
    rmmod rtl2832 &>/dev/null || true
    rmmod dvb_usb_rtl28xxu &>/dev/null || true
fi

adduser --system --home $ipath --no-create-home --quiet vdlm2dec
adduser vdlm2dec plugdev

GIT="$ipath/vdlm2dec-git"
#getGIT https://github.com/TLeconte/vdlm2dec "$branch" "$GIT"
getGIT https://github.com/wiedehopf/vdlm2dec "$branch" "$GIT"

cd "$GIT"

rm -rf build
mkdir build
cd build
if [[ $1 == "airspy" ]]; then
    cmake .. -Dairspy=ON
else
    cmake .. -Drtl=ON
fi
make -j2

BIN=/usr/local/bin/vdlm2dec
rm -f $BIN
cp -T vdlm2dec $BIN

systemctl enable vdlm2dec
systemctl restart vdlm2dec

echo "-----------------------------------"
echo "$SCRIPT_PATH completed successfully"
echo "-----------------------------------"
