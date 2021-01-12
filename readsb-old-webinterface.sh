# install readsb webinterface
rm -f /etc/lighttpd/conf-enabled/89-dump1090.conf &>/dev/null
rm -f /etc/lighttpd/conf-enabled/*dump1090-fa*.conf &>/dev/null

lighty-enable-mod readsb
lighty-enable-mod readsb-statcache

wget -O mic-readsb.zip https://github.com/Mictronics/readsb/archive/master.zip
rm -rf mic-readsb
unzip -q -d mic-readsb mic-readsb.zip
rm -rf /usr/share/readsb/html
mkdir -p /usr/share/readsb/html
cp -a mic-readsb/readsb-master/webapp/src/* /usr/share/readsb/html

rm -rf mic-readsb mic-readsb.zip

echo "All done! Webinterface should be available at http://$(ip route | grep -m1 -o -P 'src \K[0-9,.]*')/radar"
