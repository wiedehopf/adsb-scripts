#!/bin/bash

rm -f /usr/local/bin/autogain1090
rm -f /etc/default/autogain1090
rm -f /etc/cron.d/autogain1090

systemctl disable autogain1090.timer &>/dev/null
systemctl stop autogain1090.timer &>/dev/null

rm -f /lib/systemd/system/autogain1090.service
rm -f /lib/systemd/system/autogain1090.timer


# remove old naming
rm -f /usr/local/bin/dump1090-fa-autogain
rm -f /etc/default/dump1090-fa-autogain
rm -f /etc/cron.d/dump1090-fa-autogain

systemctl disable dump1090-fa-autogain.timer &>/dev/null
systemctl stop dump1090-fa-autogain.timer &>/dev/null

rm -f /lib/systemd/system/dump1090-fa-autogain.service
rm -f /lib/systemd/system/dump1090-fa-autogain.timer

systemctl daemon-reload

echo --------------
echo "autogain.sh: Uninstall complete!"

