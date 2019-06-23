#!/bin/bash


if ! dpkg -s rtl-sdr 2>/dev/null | grep 'Status.*installed' &>/dev/null
then
	if ! apt install rtl-sdr -y; then echo "Couldn't install rtl-sdr!"; exit 1; fi
fi

stop="piaware dump1090-fa dump1090-mutability dump1090"

systemctl stop fr24feed


if pgrep -a dump1090
then
	restart=yes
	for i in $stop
	do
		systemctl stop $i 2>/dev/null
	done
fi

if pgrep -a dump1090
then
	echo "dump1090 is still running, can't test the rtl-sdr receiver"
	exit 1
fi

if [[ "throttled=0x0" != $(vcgencmd get_throttled) ]]
then
	dmesg --ctime | grep voltage
	echo "Your power supply is not adequate, consider the Official Raspberry Pi power supply."
	echo "Any constant voltage supply with 5.1 to 5.2 Volts and 2.5A capability is also a good choice."
	echo "-------"
	echo "Inadequate power supplies can lead to many different problems!"
fi

echo "-----"
echo "Starting 30 second rtl_test, standby!"
echo "-----"

timeout 30 rtl_test -s 24000000

echo "-----"
echo "Test finished, there should be no or only few lost samples!"
echo "-----"

systemctl restart fr24feed

if [[ $restart == yes ]]
then
	for i in $stop
	do
		systemctl restart $i 2>/dev/null
	done
fi
