#!/bin/bash

# remove old version:
rm -f /usr/local/bin/dump1090-fa-autogain
rm -f /etc/default/dump1090-fa-autogain
rm -f /etc/cron.d/dump1090-fa-autogain

systemctl disable dump1090-fa-autogain.timer &>/dev/null
systemctl stop dump1090-fa-autogain.timer &>/dev/null

rm -f /lib/systemd/system/dump1090-fa-autogain.service
rm -f /lib/systemd/system/dump1090-fa-autogain.timer

# script to change gain

mkdir -p /usr/local/bin
cat >/usr/local/bin/autogain1090 <<"EOF"
#!/bin/bash
low=1.0
high=5.0
source /etc/default/autogain1090
ga=(0.0 0.9 1.4 2.7 3.7 7.7 8.7 12.5 14.4 15.7 16.6 19.7 20.7 22.9 25.4 28.0 29.7 32.8 33.8 36.4 37.2 38.6 40.2 42.1 43.4 43.9 44.5 48.0 49.6 -10)
tmp=/var/tmp/autogain1090
mkdir -p $tmp

APP=dump1090-fa
if [[ -f /run/dump1090-fa/stats.json ]]; then
    APP=dump1090-fa
elif [[ -f /run/readsb/stats.json ]]; then
    APP=readsb
fi

stats=/run/$APP/stats.json

if ! [[ -f $stats ]]; then echo "stats.json not found, is the decoder running?"; exit 1; fi

oldstrong=$(cat $tmp/strong 2>/dev/null)
oldtotal=$(cat $tmp/total 2>/dev/null)
if [[ -z $oldstrong ]] || [[ -z $oldtotal ]]; then
	oldstrong=0
	oldtotal=0
fi

if ! grep -qs total $stats | grep -qs -e strong_signals $stats; then
    echo "the decoder doesn't seem to be using an rtl-sdr device, can't help with that."
    exit 1
fi

strong=$(grep total $stats | sed 's/.*strong_signals":\([0-9]*\).*remote.*/\1/' | tee $tmp/strong)
total=$(grep total $stats | sed 's/.*accepted":\[\([0-9]*\).*remote.*/\1/' | tee $tmp/total)
if [[ -z $strong ]] || [[ -z $total ]]; then echo "unrecognized format: $stats"; exit 1; fi

start=$(grep total $stats | sed 's/.*start":\([0-9]*\).*/\1/')
end=$(grep total $stats | sed 's/.*end":\([0-9]*\).*/\1/')

if ! awk "BEGIN{ exit  ($end < $start + 70) }"; then
    echo "The decoder hasn't been running long enough, wait a bit!"
    exit 1
fi

if [[ $oldtotal > $total ]] || [[ $oldstrong > $strong ]] || [[ $oldtotal == $total ]]; then
	oldstrong=0
	oldtotal=0
fi

strong=$((strong - oldstrong))
total=$((total - oldtotal))

if [[ $total == 0 ]]; then
    percent=0
else
    percent=$(awk "BEGIN {printf \"%.3f\", $strong * 100 / $total}")
fi

strong=$percent

if [[ $strong == "nan" ]]; then echo "Error, can't automatically adjust gain!"; exit 1; fi
oldgain=$(grep -P -e 'gain \K[0-9-.]*' -o /etc/default/$APP)

if [[ "$oldgain" == "" ]]; then
    oldgain=44
fi

gain_index=28
for i in "${!ga[@]}"; do
    if ! awk "BEGIN{ exit  (${oldgain} <= ${ga[$i]}) }"; then
        gain_index="${i}"
        break
    fi
done

if ! awk "BEGIN{ exit  (${oldgain} > 49.6) }"; then
    gain_index=28
fi

if [[ "$oldgain" == "-10" ]]; then
    gain_index=29
fi


if ! awk "BEGIN{ exit ($strong > $low) }" && ! awk "BEGIN{ exit ($strong < $high) }"; then
	echo "No gain change needed, percentage of messages >-3dB is in nominal range. (${strong}%)"
	exit 0
fi

if ! awk "BEGIN{ exit ($strong < $low) }" && [[ $gain_index == 29 ]]; then
    echo "Gain already at maximum! (${strong}% messages >-3dB)"
    exit 0
fi

if ! awk "BEGIN{ exit ($strong < $low) }"; then
    gain_index=$(($gain_index+1))
    action=Increasing
fi

if ! awk "BEGIN{ exit ($strong > $high) }" && [[ $gain_index == 0 ]]; then
    echo "Gain already at minimum! (${strong}% messages >-3dB)"
    exit 0
fi

if ! awk "BEGIN{ exit ($strong > $high) }"; then
    gain_index=$(($gain_index-1))
    action=Decreasing
fi

gain="${ga[$gain_index]}"

if [[ $gain == "" ]]; then echo "Gain already at maximum! (${strong}% messages >-3dB)"; exit 0; fi

if [ -f /boot/piaware-config.txt ]
then
	piaware-config rtlsdr-gain $gain
fi

if ! grep gain /etc/default/$APP &>/dev/null; then sed -i -e 's/RECEIVER_OPTIONS="/RECEIVER_OPTIONS="--gain 49.6 /' /etc/default/$APP;fi
sed -i -E -e "s/--gain -?[0-9]*\.?[0-9]*/--gain $gain/" /etc/default/$APP

systemctl restart $APP

#reset numbers
echo 0 > $tmp/strong
echo 0 > $tmp/total

echo "$action gain to $gain (${strong}% messages >-3dB)"
EOF
chmod a+x /usr/local/bin/autogain1090

config_file=/etc/default/autogain1090
if ! [ -f $config_file ]; then
	cat >/etc/default/autogain1090 <<"EOF"
#!/bin/bash

low=1.0
high=9.0

ga=(0.0 0.9 1.4 2.7 3.7 7.7 8.7 12.5 14.4 15.7 16.6 19.7 20.7 22.9 25.4 28.0 29.7 32.8 33.8 36.4 37.2 38.6 40.2 42.1 43.4 43.9 44.5 48.0 49.6 -10)
EOF
fi

rm -f /etc/cron.d/autogain1090

cat >/lib/systemd/system/autogain1090.service <<"EOF"
[Unit]
Description=autogain for readsb or dump1090-fa

[Service]
ExecStart=/usr/local/bin/autogain1090
EOF

cat >/lib/systemd/system/autogain1090.timer <<"EOF"
[Unit]
Description=Nightly automic gain adjustment for readsb or dump1090-fa

[Timer]
OnCalendar=*-*-* 02:30:00
RandomizedDelaySec=30m

[Install]
WantedBy=timers.target
EOF

if grep jessie /etc/os-release >/dev/null; then
	sed -i -e '/Randomized/d' /lib/systemd/system/autogain1090.timer
fi


systemctl daemon-reload
systemctl enable autogain1090.timer
systemctl restart autogain1090.timer


echo --------------
echo "All done!"

