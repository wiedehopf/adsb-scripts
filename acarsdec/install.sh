#!/bin/bash
set -e
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR
renice 10 $$

cd /tmp

repo="https://github.com/wiedehopf/adsb-scripts"
ipath=/usr/local/share/adsb-scripts
stuff="git cmake libusb-1.0-0-dev librtlsdr-dev librtlsdr0"
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
    if cd "$TARGET" &>/dev/null && git fetch --depth 1 origin "$BRANCH" && git reset --hard FETCH_HEAD; then popd; return 0; fi
    if ! cd /tmp || ! rm -rf "$TARGET"; then popd; return 1; fi
    if git clone --depth 1 --single-branch --branch "$2" "$1" "$3"; then popd; return 0; fi
    popd; return 1;
}

# get adsb-scripts repo
getGIT "$repo" master "$ipath/git"

bash "$ipath/git/libacars/install.sh"

cd "$ipath/git/acarsdec"

cp service /lib/systemd/system/acarsdec.service
cp -n default /etc/default/acarsdec

sed -i -e "s/XX-YYYYZ/$RANDOM-$RANDOM/" /etc/default/acarsdec

# blacklist kernel driver as on ancient systems
if grep -E 'wheezy|jessie' /etc/os-release -qs; then
    echo -e 'blacklist rtl2832\nblacklist dvb_usb_rtl28xxu\n' > /etc/modprobe.d/blacklist-rtl-sdr.conf
    rmmod rtl2832 &>/dev/null || true
    rmmod dvb_usb_rtl28xxu &>/dev/null || true
fi

adduser --system --home $ipath --no-create-home --quiet acarsdec
adduser acarsdec plugdev

GIT="$ipath/acarsdec-git"
#getGIT https://github.com/TLeconte/acarsdec "$branch" "$GIT"
getGIT https://github.com/wiedehopf/acarsdec "$branch" "$GIT"

cd "$GIT"

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
