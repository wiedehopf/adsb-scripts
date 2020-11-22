#!/bin/bash
renice 10 $$
if grep -qs stretch /etc/os-release
then
    repository="http://flightaware.com/adsb/piaware/files/packages/pool/piaware/p/piaware-support/piaware-repository_3.8.1~bpo9+1_all.deb"
elif grep -qs buster /etc/os-release
then
    repository="http://flightaware.com/adsb/piaware/files/packages/pool/piaware/p/piaware-support/piaware-repository_3.8.1_all.deb"
else
    echo "Only Raspbian Stretch and Buster are supported by this script, exiting!"
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

cd /tmp
wget --timeout=30 -q -O repository.deb $repository
dpkg -i repository.deb
apt-get update
apt-get install --no-install-recommends --no-install-suggests --reinstall -y dump1090-fa

if ! /usr/bin/dump1090-fa --help >/dev/null; then
	sed -i -e '0,/nameserver/{s/nameserver.*/nameserver 8.8.8.8/}' /etc/resolv.conf
	sysctl -w net.ipv6.conf.all.disable_ipv6=0
	sysctl -w net.ipv6.conf.default.disable_ipv6=0

	wget --timeout=30 -q -O repository.deb $repository
	dpkg -i repository.deb
	apt-get update
	apt-get install --no-install-recommends --no-install-suggests --reinstall -y dump1090-fa

	if ! /usr/bin/dump1090-fa --help >/dev/null; then
		echo "Couldn't install dump1090-fa! (Maybe try again?)"
		exit 1
	fi
fi

systemctl stop fr24feed &>/dev/null
systemctl stop rb-feeder &>/dev/null

if grep -qs -e 'network_mode=false' /etc/rbfeeder.ini &>/dev/null && grep -qs -e 'mode=beast' /etc/rbfeeder.ini && grep -qs -e 'external_port=30005' /etc/rbfeeder.ini && grep -qs -e 'external_host=127.0.0.1' /etc/rbfeeder.ini
then
    sed -i -e 's/network_mode=false/network_mode=true/' /etc/rbfeeder.ini
fi

apt-get remove -y dump1090-mutability &>/dev/null
apt-get remove -y dump1090 &>/dev/null
apt-get remove -y readsb &>/dev/null

mv /etc/lighttpd/conf-enabled/89-dump1090.conf $ipath
rm /etc/lighttpd/conf-enabled/*readsb*.conf &>/dev/null

# configure fr24feed to use dump1090-fa

if [ -f /etc/fr24feed.ini ]
then
	chmod a+rw /etc/fr24feed.ini
	cp -n /etc/fr24feed.ini /usr/local/share/adsb-wiki
	if ! grep host /etc/fr24feed.ini &>/dev/null; then sed -i -e '/fr24key/a host=' /etc/fr24feed.ini; fi
	sed -i -e 's/receiver=.*/receiver="beast-tcp"\r/' -e 's/host=.*/host="127.0.0.1:30005"\r/' -e 's/bs=.*/bs="no"\r/' -e 's/raw=.*/raw="no"\r/' /etc/fr24feed.ini
else
	echo "No fr24feed configuration found, if you are using fr24feed run sudo fr24feed --signup or use the fr24feed install script"
	echo "After installing/configuring fr24feed, rerun this script to change the configuration for use of dump1090-fa"
fi

sed -i -e 's/--net-ro-interval 1/--net-ro-interval 0.1/' /etc/default/dump1090-fa

lighty-enable-mod dump1090-fa
lighty-enable-mod dump1090-fa-statcache

systemctl daemon-reload
systemctl restart fr24feed &>/dev/null
systemctl restart rb-feeder &>/dev/null
systemctl restart dump1090-fa
systemctl restart lighttpd

# script to change gain

mkdir -p /usr/local/bin
cat >/usr/local/bin/dump1090-fa-gain <<"EOF"
#!/bin/bash
gain=$(echo $1 | tr -cd '[:digit:].-')
if [[ $gain == "" ]]; then echo "Error, invalid gain!"; exit 1; fi
if [ -f /boot/piaware-config.txt ]
then
	sudo piaware-config rtlsdr-gain $gain
fi
if ! grep gain /etc/default/dump1090-fa &>/dev/null; then sed -i -e 's/RECEIVER_OPTIONS="/RECEIVER_OPTIONS="--gain 49.6 /' /etc/default/dump1090-fa; fi
sudo sed -i -E -e "s/--gain .?[0-9]*.?[0-9]* /--gain $gain /" /etc/default/dump1090-fa
sudo systemctl restart dump1090-fa
EOF
chmod a+x /usr/local/bin/dump1090-fa-gain


# set-location
cat >/usr/local/bin/dump1090-fa-set-location <<"EOF"
#!/bin/bash
if [ -f /boot/piaware-config.txt ]
then
	echo "Piaware sd-card image detected, location can only be set via your Flightaware ADS-B Statistics page!"
	exit 1
fi

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
	echo "dump1090-fa-set-location 51.52830 -0.38178"
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
	echo "dump1090-fa-set-location 51.52830 -0.38178"
	echo
	exit 1
fi

echo
echo "setting Latitude: $lat"
echo "setting Longitude: $lon"
echo
if ! grep -e '--lon' /etc/default/dump1090-fa &>/dev/null; then sed -i -e 's/DECODER_OPTIONS="/DECODER_OPTIONS="--lon -0.38178 /' /etc/default/dump1090-fa; fi
if ! grep -e '--lat' /etc/default/dump1090-fa &>/dev/null; then sed -i -e 's/DECODER_OPTIONS="/DECODER_OPTIONS="--lat 51.52830 /' /etc/default/dump1090-fa; fi
sed -i -E -e "s/--lat .?[0-9]*.?[0-9]* /--lat $lat /" /etc/default/dump1090-fa
sed -i -E -e "s/--lon .?[0-9]*.?[0-9]* /--lon $lon /" /etc/default/dump1090-fa
systemctl restart dump1090-fa
EOF
chmod a+x /usr/local/bin/dump1090-fa-set-location


echo --------------
echo "All done!"

