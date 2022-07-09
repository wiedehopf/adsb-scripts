#!/bin/bash

systemctl disable vdlm2dec
systemctl stop vdlm2dec

ipath=/usr/local/share/adsb-scripts
rm "$ipath/vdlm2dec-git" -rf
rm -v -f /lib/systemd/system/vdlm2dec.service /etc/default/vdlm2dec

