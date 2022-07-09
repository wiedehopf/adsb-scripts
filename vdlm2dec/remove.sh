#!/bin/bash

systemctl disable vdlm2dec
systemctl stop vdlm2dec

rm -v -f /lib/systemd/system/vdlm2dec.service /etc/default/vdlm2dec

