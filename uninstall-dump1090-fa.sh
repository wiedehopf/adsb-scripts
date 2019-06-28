#!/bin/bash

systemctl stop fr24feed

apt-get remove -y dump1090-fa
rm -f /etc/lighttpd/conf-enabled/89-dump1090-fa.conf
rm -f /etc/lighttpd/conf-enabled/88-dump1090-fa-statcache.conf

rm -f /usr/local/bin/dump1090-fa-gain

echo "Restoring old fr24feed settings"
mv /usr/local/share/adsb-wiki/fr24feed.ini /etc/fr24feed.ini


systemctl daemon-reload
systemctl restart fr24feed


echo --------------
echo "install-dump1090-fa: Uninstall complete!"
