#!/bin/bash
repository="https://github.com/Mictronics/readsb.git"

## REFUSE INSTALLATION ON ADSBX IMAGE

if [ -f /boot/adsb-config.txt ]; then
    echo --------
    echo "You are using the adsbx image, this setup script would mess up the configuration."
    echo --------
    echo "Exiting."
    exit 1
fi

#fix readonly remount logic in fr24feed update script, doesn't do anything when fr24 is not installed
mount -o remount,rw /
sed -i -e 's?$(mount | grep " on / " | grep rw)?{ mount | grep " on / " | grep rw; }?' /usr/lib/fr24/fr24feed_updater.sh &>/dev/null

ipath=/usr/local/share/adsb-wiki
mkdir -p $ipath

# make sure the rtl-sdr rules are present
wget -O /tmp/rtl-sdr.rules https://raw.githubusercontent.com/wiedehopf/adsb-scripts/master/osmocom-rtl-sdr.rules
cp /tmp/rtl-sdr.rules /etc/udev/rules.d/
udevadm control --reload-rules

apt-get update
apt-get install --no-install-recommends --no-install-suggests -y git build-essential debhelper libusb-1.0-0-dev \
    librtlsdr-dev librtlsdr0 pkg-config dh-systemd \
    libncurses5-dev lighttpd

rm -rf "$ipath"/git
if ! git clone --depth 1 -b dev "$repository" "$ipath/git"
then
    echo "Unable to git clone the repository"
    exit 1
fi

rm -rf "$ipath"/readsb*.deb

cd "$ipath/git"

sed -i -e 's/, libblade.*//' debian/control

if ! dpkg-buildpackage -b --build-profiles=rtlsdr --no-sign
then
    echo "Something went wrong building the debian package, exiting!"
    exit 1
fi

if ! dpkg -i ../readsb_*.deb
then
    echo "Something went wrong installing the debian package, exiting!"
    exit 1
fi

systemctl stop fr24feed &>/dev/null
systemctl stop rb-feeder &>/dev/null

if grep -qs -e 'network_mode=false' /etc/rbfeeder.ini &>/dev/null && grep -qs -e 'mode=beast' /etc/rbfeeder.ini && grep -qs -e 'external_port=30005' /etc/rbfeeder.ini && grep -qs -e 'external_host=127.0.0.1' /etc/rbfeeder.ini
then
    sed -i -e 's/network_mode=false/network_mode=true/' /etc/rbfeeder.ini
fi

apt-get remove -y dump1090-mutability &>/dev/null
apt-get remove -y dump1090 &>/dev/null
apt-get remove -y dump1090-fa &>/dev/null

rm /etc/lighttpd/conf-enabled/89-dump1090.conf &>/dev/null
rm /etc/lighttpd/conf-enabled/*dump1090-fa*.conf &>/dev/null

# configure fr24feed to use readsb

if [ -f /etc/fr24feed.ini ]
then
	chmod a+rw /etc/fr24feed.ini
	cp -n /etc/fr24feed.ini /usr/local/share/adsb-wiki
	if ! grep host /etc/fr24feed.ini &>/dev/null; then sed -i -e '/fr24key/a host=' /etc/fr24feed.ini; fi
	sed -i -e 's/receiver=.*/receiver="beast-tcp"\r/' -e 's/host=.*/host="127.0.0.1:30005"\r/' -e 's/bs=.*/bs="no"\r/' -e 's/raw=.*/raw="no"\r/' /etc/fr24feed.ini
else
	echo "No fr24feed configuration found, if you are using fr24feed run sudo fr24feed --signup or use the fr24feed install script"
	echo "If you intend to use fr24feed, use beast TCP with port 127.0.0.1 on port 30005. Or rerun this script later to fix the fr24feed configuration."
fi

lighty-enable-mod readsb
lighty-enable-mod readsb-statcache

systemctl daemon-reload
systemctl restart fr24feed &>/dev/null
systemctl restart rb-feeder &>/dev/null
systemctl restart readsb
systemctl restart lighttpd

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
echo "All done! Webinterface available at http://$(ip route | grep -m1 -o -P 'src \K[0-9,.]*')/radar"
