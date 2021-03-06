#!/bin/bash

set -e
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR
renice 10 $$

if [ -f /boot/adsb-config.txt ]; then
    echo --------
    echo "You are using the adsbx image, this setup script would mess up the configuration."
    echo --------
    echo "Exiting."
    exit 1
fi

if [ -f /boot/piaware-config.txt ]; then
    echo --------
    echo "You are using the piaware image, this setup script would mess up the configuration."
    echo --------
    echo "Exiting."
    exit 1
fi

repository="https://github.com/wiedehopf/readsb.git"

if [[ -f /usr/lib/fr24/fr24feed_updater.sh ]]; then
    #fix readonly remount logic in fr24feed update script, doesn't do anything when fr24 is not installed
    mount -o remount,rw /
    sed -i -e 's?$(mount | grep " on / " | grep rw)?{ mount | grep " on / " | grep rw; }?' /usr/lib/fr24/fr24feed_updater.sh &>/dev/null
fi

# blacklist kernel driver as on ancient systems
if grep -E 'wheezy|jessie' /etc/os-release -qs; then
    echo -e 'blacklist rtl2832\nblacklist dvb_usb_rtl28xxu\nblacklist rtl8192cu\nblacklist rtl8xxxu\n' > /etc/modprobe.d/blacklist-rtl-sdr.conf
    rmmod rtl2832 &>/dev/null || true
    rmmod dvb_usb_rtl28xxu &>/dev/null || true
    rmmod rtl8xxxu &>/dev/null || true
    rmmod rtl8192cu &>/dev/null || true
fi

ipath=/usr/local/share/adsb-wiki/readsb-install
mkdir -p $ipath

if grep -E 'wheezy|jessie' /etc/os-release -qs; then
    # make sure the rtl-sdr rules are present on ancient systems
    wget -O /tmp/rtl-sdr.rules https://raw.githubusercontent.com/wiedehopf/adsb-scripts/master/osmocom-rtl-sdr.rules
    cp /tmp/rtl-sdr.rules /etc/udev/rules.d/
fi

apt-get update || true
apt-get install --no-install-recommends --no-install-suggests -y git build-essential debhelper libusb-1.0-0-dev \
    librtlsdr-dev librtlsdr0 pkg-config dh-systemd \
    libncurses5-dev lighttpd zlib1g-dev zlib1g unzip


udevadm control --reload-rules || true

rm -rf "$ipath"/git
if ! git clone --branch stale --depth 1 "$repository" "$ipath/git"
then
    echo "Unable to git clone the repository"
    exit 1
fi

rm -rf "$ipath"/readsb*.deb

cd "$ipath/git"

export DEB_BUILD_OPTIONS=noddebs
if ! dpkg-buildpackage -b -Prtlsdr -ui -uc -us
then
    echo "Something went wrong building the debian package, exiting!"
    exit 1
fi

echo "Installing the Package"
if ! dpkg -i ../readsb_*.deb
then
    echo "Something went wrong installing the debian package, exiting!"
    exit 1
fi
echo "Package installed!"

cp -n debian/lighttpd/* /etc/lighttpd/conf-available 

systemctl stop fr24feed &>/dev/null || true
systemctl stop rb-feeder &>/dev/null || true

if grep -qs -e '--device 0' /etc/default/dump1090-fa && { ! [[ -f /etc/default/readsb ]] || grep -qs -e '--device 0' /etc/default/readsb; }; then
    systemctl disable --now dump1090-fa &>/dev/null || true
fi
systemctl disable --now dump1090-mutability &>/dev/null || true
systemctl disable --now dump1090 &>/dev/null || true

rm -f /etc/lighttpd/conf-enabled/89-dump1090.conf

# configure rbfeeder to use readsb

if [[ -f /etc/rbfeeder.ini ]]; then
    cp -n /etc/rbfeeder.ini /usr/local/share/adsb-wiki || true
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
    chmod a+rw /etc/fr24feed.ini || true
    apt-get install -y dos2unix &>/dev/null && dos2unix /etc/fr24feed.ini &>/dev/null || true
    cp -n /etc/fr24feed.ini /usr/local/share/adsb-wiki || true

    if ! grep -e 'host=' /etc/fr24feed.ini &>/dev/null; then echo 'host=' >> /etc/fr24feed.ini; fi
    if ! grep -e 'receiver=' /etc/fr24feed.ini &>/dev/null; then echo 'receiver=' >> /etc/fr24feed.ini; fi

    sed -i -e 's/receiver=.*/receiver="beast-tcp"/' -e 's/host=.*/host="127.0.0.1:30005"/' -e 's/bs=.*/bs="no"/' -e 's/raw=.*/raw="no"/' /etc/fr24feed.ini

    systemctl restart fr24feed &>/dev/null || true
fi

if (( $(cat /etc/lighttpd/conf-enabled/* | grep -c -E -e '^server.stat-cache-engine *\= *"disable"') > 1 )); then
    rm -f /etc/lighttpd/conf-enabled/88-readsb-statcache.conf
fi

systemctl enable readsb
systemctl restart readsb || true

# script to change gain

mkdir -p /usr/local/bin
cat >/usr/local/bin/readsb-gain <<"EOF"
#!/bin/bash
gain=$(echo $1 | tr -cd '[:digit:].-')
if [[ $gain == "" ]]; then echo "Error, invalid gain!"; exit 1; fi
if ! grep gain /etc/default/readsb &>/dev/null; then sed -i -e 's/RECEIVER_OPTIONS="/RECEIVER_OPTIONS="--gain 49.6 /' /etc/default/readsb; fi
sudo sed -i -E -e "s/--gain .?[0-9]*.?[0-9]* /--gain $gain /" /etc/default/readsb
sudo systemctl restart readsb
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

wget -O tar1090-install.sh https://raw.githubusercontent.com/wiedehopf/tar1090/master/install.sh
bash tar1090-install.sh /run/readsb

if ! systemctl show readsb | grep 'ExecMainStatus=0' -qs; then
    echo --------------
    echo --------------
    journalctl -u readsb | tail -n30
    echo --------------
    echo --------------
    echo "ERROR: readsb service didn't start, if inquiring about the issue please post the above 30 lines of log!"
    echo "       common issues: SDR not plugged in."
    echo "       the webinterface will show an error until readsb is running!"
    echo "       Try if a reboot solves the issue. To check if readsb is running use:"
    echo "           sudo systemctl status readsb"
    echo --------------
fi

echo --------------
echo "This used to install a no longer maintained readsb interface, it now installs tar1090 as a webinterface instead."
echo "All done! Webinterface available at http://$(ip route | grep -m1 -o -P 'src \K[0-9,.]*')/tar1090"
