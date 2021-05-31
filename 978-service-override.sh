#!/bin/bash
systemctl stop adsbexchange-978
systemctl stop adsb-exchange-978
cat >/usr/bin/adsbx-978-start <<"EOF"
#!/bin/bash

if [ -f "/boot/adsb-config.txt" ]; then
        . /boot/adsb-config.txt
	. /boot/adsbx-978env

else
        echo "NETCAT ERR:  Configuration file does not exist."
        exit 1
fi

# this script is started by adsbexchange-978.service

if [[ "${DUMP978}" == "yes" ]]; then
	echo "dump978 enabled"
	sudo systemctl enable --now dump978-fa.service
	sudo systemctl enable --now adsbexchange-978-convert.service
	sudo systemctl enable --now tar1090-978.service

	/usr/bin/adsbx-978 \
	 $RECEIVER_978_OPTIONS $DECODER_978_OPTIONS $NET_978_OPTIONS $JSON_978_OPTIONS \
	--lat ${LATITUDE} --lon ${LONGITUDE} \
	 --net-ri-port $AVR_978_IN_PORT \
	 --write-json /run/adsbexchange-978 --quiet

	#/usr/local/share/adsb-exchange-978/readsb \
	# $RECEIVER_OPTIONS $DECODER_OPTIONS $NET_OPTIONS $JSON_OPTIONS --net-ri-port $AVR_IN_PORT \
	# --write-json /run/adsb-exchange-978 --quiet

else
	sudo systemctl disable --now dump978-fa.service
	sudo systemctl disable --now adsbexchange-978-convert.service
	sudo systemctl disable --now tar1090-978.service
	exit 0
fi
EOF

chmod a+x /usr/bin/adsbx-978-start

systemctl restart adsbexchange-978
systemctl restart adsb-exchange-978

if [[ -f /etc/default/dump978-fa ]]; then
    sed -i -e 's/RECEIVER_OPTIONS.*/RECEIVER_OPTIONS="--sdr-gain 43.9 --sdr driver=rtlsdr,serial=978 --format CS8"' /etc/default/dump978-fa
    systemctl restart dump978-fa
fi

echo service override done!
