#!/bin/bash

set -e
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR
renice 10 $$

repository="https://github.com/wiedehopf/readsb.git"

ipath=/usr/local/share/adsb-wiki/readsb-install
mkdir -p $ipath

if grep -E 'wheezy|jessie' /etc/os-release -qs; then
    # make sure the rtl-sdr rules are present on ancient systems
    wget -O /tmp/rtl-sdr.rules https://raw.githubusercontent.com/wiedehopf/adsb-scripts/master/osmocom-rtl-sdr.rules
    cp /tmp/rtl-sdr.rules /etc/udev/rules.d/

    udevadm control --reload-rules || true
fi

function aptInstall() {
    if ! apt install -y --no-install-recommends --no-install-suggests "$@"; then
        apt update
        apt install -y --no-install-recommends --no-install-suggests "$@"
    fi
}

aptInstall git gcc make libusb-1.0-0-dev librtlsdr-dev librtlsdr0 libncurses-dev zlib1g-dev zlib1g

function getGIT() {
    # getGIT $REPO $BRANCH $TARGET (directory)
    if [[ -z "$1" ]] || [[ -z "$2" ]] || [[ -z "$3" ]]; then echo "getGIT wrong usage, check your script or tell the author!" 1>&2; return 1; fi
    REPO="$1"; BRANCH="$2"; TARGET="$3"; pushd .
    if cd "$TARGET" &>/dev/null && git fetch --depth 1 origin "$BRANCH" && git reset --hard FETCH_HEAD; then popd; return 0; fi
    if ! cd /tmp || ! rm -rf "$TARGET"; then popd; return 1; fi
    if git clone --depth 1 --single-branch --branch "$2" "$1" "$3"; then popd; return 0; fi
    popd; return 1;
}

if ! getGIT "$repository" "stale" "$ipath/git"
then
    echo "Unable to git clone the repository"
    exit 1
fi

cd "$ipath/git"

make -j3 AIRCRAFT_HASH_BITS=14 RTLSDR=yes

mkdir -p "$ipath/bin"
cp --remove-destination readsb viewadsb "$ipath/bin"

if [[ -n "$1" ]]; then
    mkdir -p "$1"
    cp --remove-destination readsb viewadsb "$1"
fi
