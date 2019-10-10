#!/bin/bash

# script to change gain

mkdir -p /usr/local/bin
cat >/usr/local/bin/dump1090-fa-autogain <<"EOF"
#!/bin/bash
low=1.0
high=5.0
ga=(0.0 0.9 1.4 2.7 3.7 7.7 8.7 12.5 14.4 15.7 16.6 19.7 20.7 22.9 25.4 28.0 29.7 32.8 33.8 36.4 37.2 38.6 40.2 42.1 43.4 43.9 44.5 48.0 49.6 -10)
tmp=/var/tmp/dump1090-fa-autogain
mkdir -p $tmp
stats=/run/dump1090-fa/stats.json
source /etc/default/dump1090-fa-autogain

if ! [[ -f $stats ]]; then echo "$stats not found, is dump1090-fa running?"; exit 0; fi

oldstrong=$(cat $tmp/strong 2>/dev/null)
oldtotal=$(cat $tmp/total 2>/dev/null)
if [[ -z $oldstrong ]] || [[ -z $oldtotal ]]; then
	oldstrong=0
	oldtotal=0
fi

strong=$(grep total $stats | sed 's/.*strong_signals":\([0-9]*\).*remote.*/\1/' | tee $tmp/strong)
total=$(grep total $stats | sed 's/.*accepted":\[\([0-9]*\).*remote.*/\1/' | tee $tmp/total)
if [[ -z $strong ]] || [[ -z $total ]]; then echo "unrecognized format: $stats"; exit 0; fi


if [[ $oldtotal > $total ]] || [[ $oldstrong > $strong ]] || [[ $oldtotal == $total ]]; then
	oldstrong=0
	oldtotal=0
fi

strong=$((strong - oldstrong))
total=$((total - oldtotal))

percent=$(awk "BEGIN {printf \"%.3f\", $strong * 100 / $total}")

strong=$percent

if [[ $strong == "nan" ]]; then echo "Error, can't automatically adjust gain!"; exit 1; fi
oldgain=$(grep -P -e 'gain \K[0-9-.]*' -o /etc/default/dump1090-fa)

gain_index=28
for i in "${!ga[@]}"; do
	if [[ "${ga[$i]}" = "${oldgain}" ]]; then gain_index="${i}"; fi
done

if ! awk "BEGIN{ exit ($strong > $low) }" && ! awk "BEGIN{ exit ($strong < $high) }"; then
	echo "No gain change needed, percentage of messages >-3dB is in nominal range. (${strong}%)"
	exit 0
fi

if ! awk "BEGIN{ exit ($strong < $low) }"
then gain_index=$(($gain_index+1)); action=Increasing; fi

if ! awk "BEGIN{ exit ($strong > $high) }" && [[ $gain_index == 0 ]]
then echo "Gain already at minimum! (${strong}% messages >-3dB)"; exit 0; fi

if ! awk "BEGIN{ exit ($strong > $high) }"
then gain_index=$(($gain_index-1)); action=Decreasing; fi

gain="${ga[$gain_index]}"

if [[ $gain == "" ]]; then echo "Gain already at maximum! (${strong}% messages >-3dB)"; exit 0; fi

if [ -f /boot/piaware-config.txt ]
then
	piaware-config rtlsdr-gain $gain
fi

if ! grep gain /etc/default/dump1090-fa &>/dev/null; then sed -i -e 's/RECEIVER_OPTIONS="/RECEIVER_OPTIONS="--gain 49.6 /' /etc/default/dump1090-fa;fi
sed -i -E -e "s/--gain .?[0-9]*.?[0-9]* /--gain $gain /" /etc/default/dump1090-fa

systemctl restart dump1090-fa

#reset numbers
echo 0 > $tmp/strong
echo 0 > $tmp/total

echo "$action gain to $gain (${strong}% messages >-3dB)"
EOF
chmod a+x /usr/local/bin/dump1090-fa-autogain

config_file=/etc/default/dump1090-fa-autogain
if ! [ -f $config_file ]; then
	cat >/etc/default/dump1090-fa-autogain <<"EOF"
#!/bin/bash

low=1.0
high=9.0

ga=(0.0 0.9 1.4 2.7 3.7 7.7 8.7 12.5 14.4 15.7 16.6 19.7 20.7 22.9 25.4 28.0 29.7 32.8 33.8 36.4 37.2 38.6 40.2 42.1 43.4 43.9 44.5 48.0 49.6 -10)
EOF
fi

rm -f /etc/cron.d/dump1090-fa-autogain

cat >/lib/systemd/system/dump1090-fa-autogain.service <<"EOF"
[Unit]
Description=autogain for dump1090-fa

[Service]
ExecStart=/usr/local/bin/dump1090-fa-autogain
EOF

cat >/lib/systemd/system/dump1090-fa-autogain.timer <<"EOF"
[Unit]
Description=Nightly automic gain adjustment for dump1090-fa

[Timer]
OnCalendar=*-*-* 02:30:00
RandomizedDelaySec=30m

[Install]
WantedBy=timers.target
EOF

if grep jessie /etc/os-release >/dev/null; then
	sed -i -e '/Randomized/d' /lib/systemd/system/dump1090-fa-autogain.timer
fi


systemctl daemon-reload
systemctl enable dump1090-fa-autogain.timer
systemctl restart dump1090-fa-autogain.timer


echo --------------
echo "All done!"

