#!/bin/bash
set -e
ipath=/usr/local/share/adsb-wiki/biastee
APPS="dump1090-fa readsb"

for APP in $APPS; do
    if systemctl show $APP 2>/dev/null | grep -qs 'UnitFileState=enabled'; then
        systemctl stop $APP || true
    fi
done

for APP in $APPS; do
    rm -f /etc/systemd/system/$APP.service.d/bias-t.conf
done

systemctl daemon-reload

for APP in $APPS; do
    if systemctl show $APP 2>/dev/null | grep -qs 'UnitFileState=enabled'; then
        systemctl stop $APP || true
        /usr/local/share/adsb-wiki/biastee/rtl_biast/build/src/rtl_biast -b 0 || true
        systemctl restart $APP || true
    fi
done
rm -rf $ipath

echo ----- all done ------
