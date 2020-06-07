#!/bin/bash

set -e
repository="https://github.com/Mictronics/readsb.git"

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
# remove the # in the next line to compile with biastee (might not work depending on librtlsdr version)
make -j3 RTLSDR=yes # HAVE_BIASTEE=yes

rm -f /usr/bin/readsb /usr/bin/viewadsb
cp readsb viewadsb /usr/bin

echo "Restarting readsb!"
systemctl restart readsb
echo "All done!"
