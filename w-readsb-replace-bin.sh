#!/bin/bash

set -e
repository="https://github.com/wiedehopf/readsb.git"

ipath=/usr/local/share/adsb-wiki
mkdir -p $ipath
GIT="$ipath/wiedehopf-readsb-git"
BRANCH=stale

apt update
apt install --no-install-recommends --no-install-suggests -y \
    git build-essential libusb-1.0-0-dev \
    librtlsdr-dev librtlsdr0 libncurses5-dev zlib1g-dev zlib1g

if ! cd "$GIT" || ! git fetch origin "$BRANCH" || ! git reset --hard FETCH_HEAD
then
    cd /tmp
    rm -rf "$GIT"
    if ! git clone --depth 8 --single-branch --branch "$BRANCH" "$repository" "$GIT"
    then
        echo "Unable to git clone the repository"
        exit 1
    fi
    cd "$GIT"
fi

make clean
# remove the # in the next line to compile with biastee (might not work depending on librtlsdr version)
make -j3 RTLSDR=yes AIRCRAFT_HASH_BITS=12 OPTIMIZE="-march=native" # HAVE_BIASTEE=yes

rm -f /usr/bin/readsb /usr/bin/viewadsb
cp readsb viewadsb /usr/bin

echo "Restarting readsb!"
systemctl restart readsb
echo "All done!"
