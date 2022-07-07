#!/bin/bash
renice 10 $$

set -e
repository="https://github.com/wiedehopf/readsb.git"
branch="stale"

ipath="/usr/local/share/adsb-wiki/readsb-${branch}"
cd /tmp
mkdir -p $ipath

update="no"
function aptUpdate() {
    if [[ $update != "yes" ]]; then
        apt-get update && update="yes" || true
    fi
}

if ! command -v git &>/dev/null; then
    aptUpdate
	apt-get install git || true
fi

function getGIT() {
    # getGIT $REPO $BRANCH $TARGET-DIR
    if [[ -z "$1" ]] || [[ -z "$2" ]] || [[ -z "$3" ]]; then
        echo "getGIT wrong usage, check your script or tell the author!" 1>&2
        return 1
    fi
    if ! cd "$3" &>/dev/null || ! git fetch --depth 2 origin "$2" || ! git reset --hard FETCH_HEAD; then
        if ! rm -rf "$3" || ! git clone --depth 2 --single-branch --branch "$2" "$1" "$3"; then
            return 1
        fi
    fi
    return 0
}

getGIT "$repository" "$branch" "$ipath/git"

function compile() {
	make clean && make -j2 AIRCRAFT_HASH_BITS=16 RTLSDR=yes OPTIMIZE="-march=native"
}

if ! compile; then
    aptUpdate
	apt-get install --no-install-recommends --no-install-suggests -y build-essential libusb-1.0-0-dev \
		librtlsdr-dev librtlsdr0 libncurses-dev libzstd-dev zlib1g-dev zlib1g pkg-config || true
	compile
fi

cp -f readsb /usr/bin/dump1090-fa
cp -f viewadsb /usr/bin/view1090-fa

echo "Restarting dump1090-fa (well really it's the readsb drop in but let's not split hairs)!"
systemctl restart dump1090-fa || true
