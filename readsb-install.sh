#!/bin/bash
umask 022

if [ "$(id -u)" != "0" ]; then
    echo -e "\033[33m"
    echo "This script must be ran using sudo or as root."
    echo -e "\033[37m"
    exit 1
fi

set -e
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR
renice 10 $$

if [ -f /boot/piaware-config.txt ]; then
    echo --------
    echo "You are using the piaware image, this setup script would mess up the configuration."
    echo --------
    echo "Exiting."
    exit 1
fi

BRANCH="stale"
if grep -E 'wheezy|jessie' /etc/os-release -qs; then
    BRANCH="jessie"
fi

for arg in "$@"
do
    case "$arg" in
        tag=*)
            BRANCH=$(cut -d= -f2 <<< "$arg")
            ;;
        push-30004)
            push_30004=yes
            ;;
        binary-only)
            BINARY_ONLY=yes
            ;;
        no-tar1090)
            NO_TAR1090=yes
            ;;
        sid)
            BRANCH="sid"
            ;;
        *)
            MAKE_ARGS=yes
            ;;
    esac
done

function copyNoClobber() {
    if ! [[ -f "$2" ]]; then
        cp "$1" "$2"
    fi
}

repository="https://github.com/wiedehopf/readsb.git"


if [[ -n "$push_30004" ]]; then
cat >/etc/default/readsb <<"EOF"
# readsb configuration
# This is sourced by /etc/systemd/system/default.target.wants/readsb.service as
# daemon startup configuration.

RECEIVER_OPTIONS="--device 0 --device-type rtlsdr --gain -10 --ppm 0"
DECODER_OPTIONS="--max-range 450 --write-json-every 1 --net-connector 127.0.0.1,30004,beast_out"
NET_OPTIONS="--net --net-heartbeat 60 --net-ro-size 1280 --net-ro-interval 0.05 --net-ri-port 20001 --net-ro-port 20002 --net-sbs-port 20003 --net-bi-port 20004,20104 --net-bo-port 20005"
JSON_OPTIONS="--json-location-accuracy 2 --range-outline-hours 24"
EOF
fi

if [[ -f /usr/lib/fr24/fr24feed_updater.sh ]]; then
    #fix readonly remount logic in fr24feed update script, doesn't do anything when fr24 is not installed
    mount -o remount,rw / &>/dev/null || true
    sed -i -e 's?$(mount | grep " on / " | grep rw)?{ mount | grep " on / " | grep rw; }?' /usr/lib/fr24/fr24feed_updater.sh &>/dev/null || true
fi

# blacklist kernel driver as on ancient systems
if grep -E 'wheezy|jessie' /etc/os-release -qs; then
    echo -e 'blacklist rtl2832\nblacklist dvb_usb_rtl28xxu\n' > /etc/modprobe.d/blacklist-rtl-sdr.conf
    rmmod rtl2832 &>/dev/null || true
    rmmod dvb_usb_rtl28xxu &>/dev/null || true
fi

ipath=/usr/local/share/adsb-wiki/readsb-install
mkdir -p $ipath

if grep -E 'wheezy|jessie' /etc/os-release -qs; then
    # make sure the rtl-sdr rules are present on ancient systems
    wget -O /tmp/rtl-sdr.rules https://raw.githubusercontent.com/wiedehopf/adsb-scripts/master/osmocom-rtl-sdr.rules
    cp /tmp/rtl-sdr.rules /etc/udev/rules.d/
fi

function aptInstall() {
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends --no-install-suggests "$@" &>/dev/null; then
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends --no-install-suggests "$@"
    fi
}

if command -v apt &>/dev/null; then
    packages=(git gcc make libusb-1.0-0-dev ncurses-dev ncurses-bin zlib1g-dev zlib1g pkg-config libc6-dev)
    if ! grep -E 'wheezy|jessie' /etc/os-release -qs; then
        packages+=(libzstd-dev libzstd1)
    fi
    if ! command -v nginx &>/dev/null && [[ -z "$NO_TAR1090" ]] ; then
        packages+=(lighttpd)
    fi
    packages+=(librtlsdr-dev)
    if grep -qs -i -e 'ubuntu' /etc/os-release; then
        aptInstall librtlsdr0 || aptInstall librtlsdr2
    else
        packages+=(librtlsdr0)
    fi
    aptInstall "${packages[@]}"
fi

udevadm control --reload-rules || true
udevadm trigger || true

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
if ! getGIT "$repository" "$BRANCH" "$ipath/git"
then
    echo "Unable to git clone the repository"
    exit 1
fi

rm -rf "$ipath"/readsb*.deb
cd "$ipath/git"

make clean
THREADS=$(( $(grep -c ^processor /proc/cpuinfo) - 1 ))
THREADS=$(( THREADS > 0 ? THREADS : 1 ))
CFLAGS="-O2 -march=native -mtune=native"

# disable unaligned access for arm 32bit ...
if uname -m | grep -qs -e arm -e aarch64 && gcc -mno-unaligned-access hello.c -o /dev/null &>/dev/null; then
    CFLAGS+=" -mno-unaligned-access"
fi

if [[ $1 == "sanitize" ]]; then
    CFLAGS+="-fsanitize=address -static-libasan"
    if ! make "-j${THREADS}" RTLSDR=yes OPTIMIZE="$CFLAGS"; then
        if grep -qs /etc/os-release 'bookworm'; then aptInstall libasan8;
        elif grep -qs /etc/os-release 'bullseye'; then aptInstall libasan6;
        elif grep -qs /etc/os-release 'buster'; then aptInstall libasan5;
        fi
        make "-j${THREADS}" RTLSDR=yes OPTIMIZE="$CFLAGS"
    fi
else
    if [[ -n "$MAKE_ARGS" ]]; then
        make "-j${THREADS}" RTLSDR=yes OPTIMIZE="$CFLAGS" "$@"
    else
        make "-j${THREADS}" RTLSDR=yes OPTIMIZE="$CFLAGS"
    fi
fi


rm -f /usr/bin/readsb /usr/bin/viewadsb
cp -f readsb /usr/bin/readsb
cp -f viewadsb /usr/bin/viewadsb

cp -f debian/readsb.service /lib/systemd/system/readsb.service
copyNoClobber debian/readsb.default /etc/default/readsb

if [[ -n "$BINARY_ONLY" ]]; then
    systemctl restart readsb
    echo /usr/bin/readsb has been replaced with an updated version
    exit 0
fi

if ! id -u readsb &>/dev/null
then
    adduser --system --no-create-home readsb
    adduser readsb plugdev # SDR access (via udev rules)
    adduser readsb dialout # serial access
fi

apt remove -y dump1090-fa &>/dev/null || true
apt remove -y dump1090-mutability &>/dev/null || true
apt remove -y dump1090 &>/dev/null || true

rm -f /etc/lighttpd/conf-enabled/89-dump1090.conf

# configure rbfeeder to use readsb

if [[ -f /etc/rbfeeder.ini ]]; then
    systemctl stop rb-feeder &>/dev/null || true
    copyNoClobber /etc/rbfeeder.ini /usr/local/share/adsb-wiki || true
    sed -i -e '/network_mode/d' -e '/\[network\]/d' -e '/mode=/d' -e '/external_port/d' -e '/external_host/d' /etc/rbfeeder.ini
    sed -i -e 's/\[client\]/\0\nnetwork_mode=true/' /etc/rbfeeder.ini
    cat >>/etc/rbfeeder.ini <<"EOF"
[network]
mode=beast
external_port=30005
external_host=127.0.0.1
EOF
    pkill -9 rbfeeder || true
    systemctl restart rbfeeder &>/dev/null || true
fi

# configure fr24feed to use readsb

if [ -f /etc/fr24feed.ini ]
then
    systemctl stop fr24feed &>/dev/null || true
    chmod a+rw /etc/fr24feed.ini || true
    apt-get install -y dos2unix &>/dev/null && dos2unix /etc/fr24feed.ini &>/dev/null || true
    copyNoClobber /etc/fr24feed.ini /usr/local/share/adsb-wiki || true

    if ! grep -e 'host=' /etc/fr24feed.ini &>/dev/null; then echo 'host=' >> /etc/fr24feed.ini; fi
    if ! grep -e 'receiver=' /etc/fr24feed.ini &>/dev/null; then echo 'receiver=' >> /etc/fr24feed.ini; fi

    sed -i -e 's/receiver=.*/receiver="beast-tcp"/' -e 's/host=.*/host="127.0.0.1:30005"/' \
        -e 's/mlat=.*/mlat="no"/' -e 's/bs=.*/bs="no"/' -e 's/raw=.*/raw="no"/' /etc/fr24feed.ini

    systemctl restart fr24feed &>/dev/null || true
fi

systemctl enable readsb
systemctl restart readsb || true

# script to change gain

mkdir -p /usr/local/bin
cat >/usr/local/bin/readsb-gain <<"EOF"
#!/bin/bash
validre='^([^ ]*)$'
gain="$1"
if ! [[ $gain =~ $validre ]] ; then echo "Error, invalid gain!"; exit 1; fi
if ! grep gain /etc/default/readsb &>/dev/null; then sudo sed -i -e 's/RECEIVER_OPTIONS="/RECEIVER_OPTIONS="--gain 49.6 /' /etc/default/readsb; fi
sudo sed -i -E -e "/^[[:space:]]*#/b; /--gain/ s/--gain[ =][^ \"]*/--gain $gain/" /etc/default/readsb
echo "$gain" | sudo tee /run/readsb/setGain || sudo systemctl restart readsb
EOF
chmod a+x /usr/local/bin/readsb-gain


# set-location
cat >/usr/local/bin/readsb-set-location <<"EOF"
#!/bin/bash

lat=$(echo $1 | tr -cd '[:digit:].-')
lon=$(echo $2 | tr -cd '[:digit:].-')

if ! awk "BEGIN{ exit ($lat > 90) }" || ! awk "BEGIN{ exit ($lat < -90) }"; then
    echo
    echo "Invalid latitude: $lat"
    echo "Latitude must be between -90 and 90"
    echo
    echo "Example format for latitude: 51.528308"
    echo
    echo "Usage:"
    echo "readsb-set-location 51.52830 -0.38178"
    echo
    exit 1
fi
if ! awk "BEGIN{ exit ($lon > 180) }" || ! awk "BEGIN{ exit ($lon < -180) }"; then
    echo
    echo "Invalid longitude: $lon"
    echo "Longitude must be between -180 and 180"
    echo
    echo "Example format for latitude: -0.38178"
    echo
    echo "Usage:"
    echo "readsb-set-location 51.52830 -0.38178"
    echo
    exit 1
fi

echo
echo "setting Latitude: $lat"
echo "setting Longitude: $lon"
echo
if ! grep -e '--lon' /etc/default/readsb &>/dev/null; then sed -i -e 's/DECODER_OPTIONS="/DECODER_OPTIONS="--lon -0.38178 /' /etc/default/readsb; fi
if ! grep -e '--lat' /etc/default/readsb &>/dev/null; then sed -i -e 's/DECODER_OPTIONS="/DECODER_OPTIONS="--lat 51.52830 /' /etc/default/readsb; fi
sed -i -E -e "s/--lat .?[0-9]*.?[0-9]* /--lat $lat /" /etc/default/readsb
sed -i -E -e "s/--lon .?[0-9]*.?[0-9]* /--lon $lon /" /etc/default/readsb
systemctl restart readsb
EOF
chmod a+x /usr/local/bin/readsb-set-location


echo --------------
cd "$ipath"

if [[ -z "$NO_TAR1090" ]] ; then
    wget -O tar1090-install.sh https://raw.githubusercontent.com/wiedehopf/tar1090/master/install.sh
    bash tar1090-install.sh /run/readsb
fi

if ! systemctl show readsb | grep 'ExecMainStatus=0' -qs; then
    echo --------------
    echo --------------
    journalctl -u readsb | tail -n30 | tee journal.log
    echo --------------
    echo --------------
    if grep -qs -e 'Permission denied' journal.log; then
        echo "ERROR: readsb permission issue, please perform a reboot using this command: sudo reboot"
        echo "--------------"
        echo "After the reboot, the webinterface will be available at http://$(ip route get 1.2.3.4 | grep -m1 -o -P 'src \K[0-9,.]*')/tar1090"
    else
        echo "ERROR: readsb service didn't start."
        echo "       common issues: SDR not plugged in."
        echo "       the webinterface will show an error until readsb is running!"
        echo "       If you can't fix the issue:"
        echo "            Open a github issue or contact wiedehopf on discord (https://discord.gg/DxU4VG37JS) and post the above 30 lines of log!"
        echo --------------
    fi
else
    echo "Don't forget to set your location using decimal latitude and longitude:"
    echo
    if echo $PATH | grep -qs '/usr/local/bin'; then
        echo "sudo readsb-set-location 50.12344 10.23429"
    else
        echo "sudo /usr/local/bin/readsb-set-location 50.12344 10.23429"
    fi
    echo
fi
