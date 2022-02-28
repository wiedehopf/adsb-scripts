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

if grep -qs stretch /etc/os-release
then
    repository="http://flightaware.com/adsb/piaware/files/packages/pool/piaware/p/piaware-support/piaware-repository_3.8.1~bpo9+1_all.deb"
elif grep -qs buster /etc/os-release
then
    repository="http://flightaware.com/adsb/piaware/files/packages/pool/piaware/p/piaware-support/piaware-repository_6.1_all.deb"
elif grep -qs bullseye /etc/os-release
then
    repository="http://flightaware.com/adsb/piaware/files/packages/pool/piaware/p/piaware-support/piaware-repository_7.1_all.deb"
else
    echo "Only Raspbian Stretch and Buster are supported by this script, exiting!"
    exit 1
fi

if [[ -f /usr/lib/fr24/fr24feed_updater.sh ]]; then
    #fix readonly remount logic in fr24feed update script, doesn't do anything when fr24 is not installed
    mount -o remount,rw /
    sed -i -e 's?$(mount | grep " on / " | grep rw)?{ mount | grep " on / " | grep rw; }?' /usr/lib/fr24/fr24feed_updater.sh &>/dev/null
fi

ipath=/usr/local/share/adsb-wiki
mkdir -p $ipath

cd /tmp
wget --timeout=30 -q -O repository.deb $repository
dpkg -i repository.deb
apt-get update || true
apt-get install --no-install-recommends --no-install-suggests --reinstall -y dump1090-fa

if ! /usr/bin/dump1090-fa --help >/dev/null; then
    echo "Couldn't install dump1090-fa! (Maybe try again?)"
    exit 1
fi

udevadm control --reload-rules || true

systemctl stop fr24feed &>/dev/null || true
systemctl stop rb-feeder &>/dev/null || true

if grep -qs -e '--device 0' /etc/default/readsb && { ! [[ -f /etc/default/dump1090-fa ]] || grep -qs -e '--device 0' /etc/default/dump1090-fa; }; then
    systemctl disable --now readsb &>/dev/null || true
fi
systemctl disable --now dump1090-mutability &>/dev/null || true
systemctl disable --now dump1090 &>/dev/null || true

rm -f /etc/lighttpd/conf-enabled/89-dump1090.conf
rm -f /etc/lighttpd/conf-enabled/*readsb*.conf &>/dev/null

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

# configure fr24feed to use dump1090-fa

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

sed -i -e 's/--net-ro-interval 1/--net-ro-interval 0.1/' /etc/default/dump1090-fa || true

lighty-enable-mod dump1090-fa || true
lighty-enable-mod dump1090-fa-statcache || true

mv -f /etc/lighttpd/conf-available/89-dump1090-fa.conf.dpkg-dist /etc/lighttpd/conf-available/89-dump1090-fa.conf &>/dev/null || true

if (( $(cat /etc/lighttpd/conf-enabled/* | grep -c -E -e '^server.stat-cache-engine *\= *"disable"') > 1 )); then
    rm -f /etc/lighttpd/conf-enabled/88-dump1090-fa-statcache.conf
fi

systemctl daemon-reload
systemctl restart lighttpd || true

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
if grep -qs /etc/default/dump1090-fa -e 'CONFIG_STYLE.*6'; then
    echo "dump1090-fa 6 config style not supported, just edit the file yourself!"
    echo "Support might be added in the future, in the meantime consider using readsb if you don't want to edit the config by hand:"
    echo "https://github.com/wiedehopf/adsb-scripts/wiki/Automatic-installation-for-readsb"
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
systemctl restart dump1090-fa
echo --------------
echo "All done!"

