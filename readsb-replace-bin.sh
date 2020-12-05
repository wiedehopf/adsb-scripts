#!/bin/bash
renice 10 $$

set -e
repository="https://github.com/wiedehopf/readsb.git"
branch="stale"

ipath="/usr/local/share/adsb-wiki/readsb-${branch}"
mkdir -p $ipath

apt-get update
apt-get install --no-install-recommends --no-install-suggests -y git build-essential libusb-1.0-0-dev \
    librtlsdr-dev librtlsdr0 libncurses5-dev

function gitUpdate() {
    { cd "$2" &>/dev/null && git rev-parse; } ||
    { cd "$2" &>/dev/null && git fetch --depth 1 origin "$3" && git reset --hard FETCH_HEAD; } ||
    { cd && rm -rf "$1" && git clone --depth 1 "$1" "$2"; }

    if ! cd "$2" || ! git rev-parse
    then
        echo "Unable to download files, exiting! (Maybe try again?)"
        exit 1
    fi
}

gitUpdate "$repository" "$ipath/git" "$branch"

make clean
make -j2 AIRCRAFT_HASH_BITS=12 RTLSDR=yes OPTIMIZE="-march=native"


rm -f /usr/bin/viewadsb
cp viewadsb /usr/bin

for bin in readsb adsbxfeeder feed-asdbx; do
    rm -f "/usr/bin/$bin"
    cp readsb "/usr/bin/$bin"
done

echo "Restarting readsb!"
systemctl restart readsb
echo "All done! Reboot recommended."
