#!/bin/bash

view1090-fa --no-interactive \
	| grep -F -e 'CPR longitude' -B10 \
	| grep -F -e '--' -e RSSI -e latitude -e longitude -e altitude: \
	| awk '!/--$/ { printf("%s\t", $0); next } 1' \
	| sed \
		-e 's/RSSI: //' \
		-e 's/ dBFS	  Baro altitude: /,/' \
		-e 's/ ft	  CPR latitude:  /,/' \
		-e 's/ ([0-9]*)	  CPR longitude: /,/' \
		-e 's/ ([0-9]*)	--//' \
	| sed '/ /d'
