#!/bin/bash

mkdir -p /usr/local/bin
rm -f /usr/local/bin/dump1090-fa-autogain
rm -f /etc/default/dump1090-fa-autogain
rm -f /etc/cron.d/dump1090-fa-autogain

systemctl disable dump1090-fa-autogain.timer
systemctl stop dump1090-fa-autogain.timer

rm -f /lib/systemd/system/dump1090-fa-autogain.service
rm -f /lib/systemd/system/dump1090-fa-autogain.timer

systemctl daemon-reload


echo --------------
echo "dump1090-fa-autogain.sh: Uninstall complete!"

