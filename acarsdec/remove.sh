#!/bin/bash

systemctl disable acarsdec
systemctl stop acarsdec

ipath=/usr/local/share/adsb-scripts
rm "$ipath/acarsdec-git" -rf
rm -v -f /lib/systemd/system/acarsdec.service /etc/default/acarsdec

