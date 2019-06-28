#!/bin/bash

ipath=/usr/local/share/adsb-wiki

systemctl stop fr24feed

apt-get remove -y dump1090-fa
rm -f /etc/lighttpd/conf-enabled/89-dump1090-fa.conf
rm -f /etc/lighttpd/conf-enabled/88-dump1090-fa-statcache.conf

rm -f /usr/local/bin/dump1090-fa-gain

echo "Restoring old fr24feed settings"
mv $ipath/fr24feed.ini /etc/fr24feed.ini
mv $ipath/89-dump1090.conf /etc/lighttpd/conf-enabled

echo "This might take a moment, give it 5 minutes please."
bash /usr/lib/fr24/install_dump1090.sh


systemctl daemon-reload
systemctl restart fr24feed
systemctl restart lighttpd


echo --------------
echo "install-dump1090-fa: Uninstall complete!"
