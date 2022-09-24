#!/bin/bash

systemctl disable dumpvdl2
systemctl stop dumpvdl2

ipath=/usr/local/share/adsb-scripts
rm "$ipath/dumpvdl2-git" -rf
rm -v -f /lib/systemd/system/dumpvdl2.service /etc/default/dumpvdl2

