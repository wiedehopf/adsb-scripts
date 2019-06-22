#!/bin/bash

# script to change gain

mkdir -p /usr/local/bin
cat >/usr/local/bin/dump1090-fa-autogain <<"EOF"
#!/bin/bash
source /etc/default/dump1090-fa-autogain
strong=$(awk "$(cat /run/dump1090-fa/stats.json | grep total | sed 's/.*accepted":\[\([0-9]*\).*strong_signals":\([0-9]*\).*/BEGIN {printf "%.3f" , \2 * 100 \/ \1}/')")

if [[ $strong == "nan" ]]; then echo "Error, can't automatically adjust gain!"; exit 1; fi
oldgain=$(grep -P -e 'gain \K[0-9-.]*' -o /etc/default/dump1090-fa)

gain_index=28
for i in "${!ga[@]}"; do
	if [[ "${ga[$i]}" = "${oldgain}" ]]; then gain_index="${i}"; fi
done

if ! awk "BEGIN{ exit ($strong > $low) }" && ! awk "BEGIN{ exit ($strong < $high) }"
then echo "No gain change needed, percentage of messages >-3dB is in nominal range. (${strong}%)"
	if [[ $(date +%w) == 0 ]]; then systemctl restart dump1090-fa; fi
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
echo "$action gain to $gain (${strong}% messages >-3dB)"
EOF
chmod a+x /usr/local/bin/dump1090-fa-autogain

cat >/etc/default/dump1090-fa-autogain <<"EOF"
#!/bin/bash

low=1.0
high=5.0

ga=(0.0 0.9 1.4 2.7 3.7 7.7 8.7 12.5 14.4 15.7 16.6 19.7 20.7 22.9 25.4 28.0 29.7 32.8 33.8 36.4 37.2 38.6 40.2 42.1 43.4 43.9 44.5 48.0 49.6 -10)
EOF

cat >/etc/cron.d/dump1090-fa-autogain <<"EOF"
45 2 * * * root /bin/bash /usr/local/bin/dump1090-fa-autogain

EOF

echo --------------
echo "All done!"

