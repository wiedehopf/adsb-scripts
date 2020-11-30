#!/bin/bash
renice 10 $$

set -e
repository="https://github.com/wiedehopf/readsb.git"

ipath=/usr/local/share/adsb-wiki
mkdir -p $ipath

apt-get update
apt-get install --no-install-recommends --no-install-suggests -y git build-essential libusb-1.0-0-dev \
    librtlsdr-dev librtlsdr0 libncurses5-dev

if ! git clone --depth 1 -b dev "$repository" "$ipath/git" 2>/dev/null && ! cd "$ipath/git"
then
    echo "Unable to git clone the repository"
    exit 1
fi

cd "$ipath/git"

git fetch
git reset --hard origin/dev

make clean
make -j2 AIRCRAFT_HASH_BITS=12 RTLSDR=yes OPTIMIZE="-march=native"


rm -f /usr/bin/readsb /usr/bin/viewadsb
cp readsb viewadsb /usr/bin

rm -f /usr/bin/adsbxfeeder
cp readsb /usr/bin/adsbxfeeder

echo "Restarting readsb!"
systemctl restart readsb
echo "All done! Reboot recommended."
