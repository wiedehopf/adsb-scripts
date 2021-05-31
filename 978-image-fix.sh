#!/bin/bash
rm -f /usr/local/share/adsb-exchange-978/convert.sh /usr/local/share/uat2esnt
wget -O /usr/local/share/adsb-exchange-978/convert.sh https://github.com/adsbxchange/adsbexchange-978/raw/master/dropin.sh
wget -O /usr/local/share/uat2esnt https://github.com/adsbxchange/adsbexchange-978/raw/master/uat2esnt
chmod a+x /usr/local/share/adsb-exchange-978/convert.sh /usr/local/share/uat2esnt

echo 978 fix done
