#!/bin/bash
set -e
ipath=/usr/local/share/adsb-wiki/biastee
APPS="dump1090-fa readsb"
rm -rf $ipath

for APP in $APPS; do
    rm -f /etc/systemd/system/$APP.service.d/bias-t.conf
done

systemctl daemon-reload

for APP in $APPS; do
    if systemctl show readsb 2>/dev/null | grep -qs 'UnitFileState=enabled'; then
        systemctl restart $APP || true
    fi
done
