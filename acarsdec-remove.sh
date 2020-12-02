#!/bin/bash

systemctl disable acarsdec
systemctl stop acarsdec

rm -v -f /lib/systemd/system/acarsdec.service /etc/default/acarsdec

