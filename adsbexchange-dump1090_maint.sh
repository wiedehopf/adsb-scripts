#!/bin/bash
if [ -f "/tmp/adsbx-params" ]; then
        . /tmp/adsbx-params
else
        echo "DUMP1090 ERR:  Configuration file does not exist."
        exit 0
fi

if [ ${DUMP} = "no" ]; then
 exit 1
fi

if [ ${DUMP} = "yes" ]; then

if [ ! -d /run/dump1090-mutability ]; then
	mkdir /run/dump1090-mutability
	chown pi:pi /run/dump1090-mutability
else
	sleep 5
fi

if [ -z ${ADSBXNAME} ]; then
        ADSBNAME=img-custom
        ADSBXNAME=$ADSBNAME-$(cat /sys/class/net/eth0/address | cut -d ':' -f 4,5,6 | tr -d : )
else
        ADSBXNAME=$ADSBXNAME-$(cat /sys/class/net/eth0/address | cut -d ':' -f 4,5,6 | tr -d : )
fi

if [ -z ${LATITUDE} ] || [ -z ${LONGITUDE} ]; then
	MLATITUDE=$(ps -eaf | grep [d]ump1090 | awk -F'--lat' '{print $2}' | awk '{print $1}')
	MLONGITUDE=$(ps -eaf | grep [d]ump1090 | awk -F'--lon' '{print $2}' | awk '{print $1}')
else
	MLATITUDE=${LATITUDE}
	MLONGITUDE=${LONGITUDE}
fi

  while true
   do

  export MLATITUDE=$MLATITUDE
  export MLONGITUDE=$MLONGITUDE
  echo -e  '\n\n Running dump1090 with --quiet --net --ppm 0 --aggressive --fix --lat' ${MLATITUDE} '--lon' ${MLONGITUDE} '--max-range 400 --net-ri-port 0 --net-ro-port 30002 --net-bi-port 30004,30104 --net-bo-port 30005 --net-sbs-port 30003 --net-heartbeat 30 --net-ro-size 5000 --net-ro-interval 1 --net-buffer 2 --write-json /run/dump1090-mutability --write-json-every 1 --gain -10 --json-location-accuracy 1 \n\n'
  su pi -c '/usr/bin/readsb --quiet --net --ppm 0 --fix --lat $MLATITUDE --lon $MLONGITUDE --max-range 450 --net-ri-port 0 --net-ro-port 30002 --net-bi-port 30004,30104 --net-bo-port 30005 --net-sbs-port 30003 --net-heartbeat 30 --net-ro-size 1280 --net-ro-interval 0.2 --net-buffer 2 --stats-every 3600 --write-json /run/dump1090-mutability --write-json-every 1 --gain -10 --json-location-accuracy 2'
  sleep 30

  done

else
  exit 0
fi


