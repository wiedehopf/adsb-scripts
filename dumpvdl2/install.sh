#!/bin/bash
umask 022
set -e
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd)/$(basename "$0")"
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR
renice 10 $$

cd /tmp

repo="https://github.com/wiedehopf/adsb-scripts"
ipath=/usr/local/share/adsb-scripts
stuff="build-essential cmake git libglib2.0-dev pkg-config libusb-1.0-0-dev librtlsdr-dev librtlsdr0"
branch="master"

if [[ -n $1 ]]; then
    branch="$1"
fi

apt install -y $stuff || apt update && apt install -y $stuff || true

mkdir -p $ipath

function getGIT() {
    # getGIT $REPO $BRANCH $TARGET (directory)
    if [[ -z "$1" ]] || [[ -z "$2" ]] || [[ -z "$3" ]]; then echo "getGIT wrong usage, check your script or tell the author!" 1>&2; return 1; fi
    REPO="$1"; BRANCH="$2"; TARGET="$3"; pushd .
    if cd "$TARGET" &>/dev/null && git remote set-url origin "$REPO" &&  git fetch --depth 1 origin "$BRANCH" && git reset --hard FETCH_HEAD; then popd; return 0; fi
    if ! cd /tmp || ! rm -rf "$TARGET"; then popd; return 1; fi
    if git clone --depth 1 --single-branch --branch "$2" "$1" "$3"; then popd; return 0; fi
    popd; return 1;
}

# get adsb-scripts repo
getGIT "$repo" master "$ipath/git"

bash "$ipath/git/libacars/install.sh"

cd "$ipath/git/dumpvdl2"

cp service /lib/systemd/system/dumpvdl2.service
cp -n default /etc/default/dumpvdl2

sed -i -e "s/XX-YYYYZ/$RANDOM-$RANDOM/" /etc/default/dumpvdl2

# blacklist kernel driver as on ancient systems
if grep -E 'wheezy|jessie' /etc/os-release -qs; then
    echo -e 'blacklist rtl2832\nblacklist dvb_usb_rtl28xxu\n' > /etc/modprobe.d/blacklist-rtl-sdr.conf
    rmmod rtl2832 &>/dev/null || true
    rmmod dvb_usb_rtl28xxu &>/dev/null || true
fi

adduser --system --home $ipath --no-create-home --quiet dumpvdl2
adduser dumpvdl2 plugdev

GIT="$ipath/dumpvdl2-git"
getGIT https://github.com/szpajder/dumpvdl2 "$branch" "$GIT"

cd "$GIT"

rm -rf build
mkdir build
cd build
sed -i -e 's/#define RTL_OVERSAMPLE.*/#define RTL_OVERSAMPLE 12/' ../src/rtl.h
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j2

BIN=/usr/local/bin/dumpvdl2
rm -f $BIN
cp -T src/dumpvdl2 $BIN

systemctl enable dumpvdl2
systemctl restart dumpvdl2

echo "-----------------------------------"
echo "$SCRIPT_PATH completed successfully"
echo "-----------------------------------"
