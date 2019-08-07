#!/bin/bash

view1090-fa --no-interactive \
	| grep -F -e CPR -B7 \
	| grep -F -e RSSI -e latitude -e longitude -e altitude: \
	| awk '{c="\n"} NR%4 {c=""} { printf("%s%s", $0, c) } ' \
	| sed -u -e 's/  Baro altitude: //' -e 's/  CPR latitude:  //' \
	-e 's/  CPR longitude: //' -e 's/RSSI: //' -e 's/ dBFS/,/' \
	-e 's/ ([0-9]*)/,/g' -e 's/ ft/,/' -e 's/,$//' \
	| sed '/([0-9]*)/d'
