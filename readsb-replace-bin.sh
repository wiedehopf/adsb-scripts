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

gitUpdate "$repository" "$ipath/git" "$branch"

function compile() {
	make clean && make -j2 AIRCRAFT_HASH_BITS=12 RTLSDR=yes OPTIMIZE="-march=native"
}

if ! compile; then
    aptUpdate
	apt-get install --no-install-recommends --no-install-suggests -y build-essential libusb-1.0-0-dev \
		librtlsdr-dev librtlsdr0 libncurses5-dev || true
	compile
fi

rm -f /usr/bin/viewadsb
cp viewadsb /usr/bin

for bin in readsb adsbxfeeder feed-asdbx; do
    FILE="/usr/bin/$bin"
    if [[ -f $FILE ]]; then
        rm -f "$FILE"
        cp readsb "$FILE"
    fi
done

echo "Restarting readsb!"
systemctl restart readsb || true
systemctl restart adsbexchange-feed &>/dev/null || true
systemctl restart adsbexchange-978 &>/dev/null || true
echo "All done! Reboot recommended."
