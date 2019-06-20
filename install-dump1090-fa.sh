#!/bin/bash
repository="http://flightaware.com/adsb/piaware/files/packages/pool/piaware/p/piaware-support/piaware-repository_3.7.1_all.deb"

#fix readonly remount logic in fr24feed update script, doesn't do anything when fr24 is not installed
mount -o remount,rw /
sed -i -e 's?$(mount | grep " on / " | grep rw)?{ mount | grep " on / " | grep rw; }?' /usr/lib/fr24/fr24feed_updater.sh &>/dev/null

cd /tmp
wget --timeout=30 -q -O repository.deb $repository
dpkg -i repository.deb
apt-get update

if ! apt-get install --reinstall -y dump1090-fa
then
	echo "Couldn't install dump1090-fa! (Maybe try again?)"
	exit 1
fi

systemctl stop fr24feed

apt-get remove -y dump1090-mutability &>/dev/null
apt-get remove -y dump1090 &>/dev/null
rm -f /etc/lighttpd/conf-enabled/89-dump1090.conf

# configure fr24feed to use dump1090-fa

if [ -f /etc/fr24feed.ini ]
then
	chmod a+rw /etc/fr24feed.ini
	cp -n /etc/fr24feed.ini /etc/fr24feed.ini.backup
	if ! grep host /etc/fr24feed.ini &>/dev/null; then sed -i -e '/fr24key/a host=' /etc/fr24feed.ini; fi
	sed -i -e 's/receiver=.*/receiver="beast-tcp"\r/' -e 's/host=.*/host="127.0.0.1:30005"\r/' -e 's/bs=.*/bs="no"\r/' -e 's/raw=.*/raw="no"\r/' /etc/fr24feed.ini
else
	echo "no fr24feed configuration found, if you are using fr24feed run sudo fr24feed --signup or use the fr24feed install script"
fi

systemctl daemon-reload
systemctl restart fr24feed dump1090-fa

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
# some day


echo --------------
echo "All done!"

