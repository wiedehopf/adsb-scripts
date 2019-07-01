#!/bin/bash

# Fetch daily data from rrds

rrdtool fetch /var/lib/collectd/rrd/localhost/dump1090-localhost/dump1090_messages-local_accepted.rrd AVERAGE -e midnight today -s end-7day -r 3m -a > /tmp/messages_l
rrdtool fetch /var/lib/collectd/rrd/localhost/dump1090-localhost/dump1090_messages-remote_accepted.rrd AVERAGE -e midnight today -s end-7day -r 3m -a > /tmp/messages_r
rrdtool fetch /var/lib/collectd/rrd/localhost/dump1090-localhost/dump1090_aircraft-recent.rrd AVERAGE -e midnight today -s end-7day -r 3m -a > /tmp/aircraft

# Remove headers and extraneous :

sed -i -e 's/://' -e 's/\,/\./g' /tmp/messages_l
sed -i -e 's/://' -e 's/\,/\./g' /tmp/messages_r
sed -i -e 's/://' -e 's/\,/\./g' /tmp/aircraft

sed -i -e '1d;2d' /tmp/messages_l
sed -i -e '1d;2d' /tmp/messages_r
sed -i -e '1d;2d' /tmp/aircraft

# Combine both files to create space separated data file for use by gnuplot

join -o 1.1 1.2 2.2 /tmp/aircraft /tmp/messages_l > /tmp/tmp
join -o 1.2 1.3 2.2 /tmp/tmp /tmp/messages_r > /tmp/$(date -I --date=yesterday)-scatter

cd /tmp

gnuplot /dev/stdin <<"EOF"
date = system("date -I --date=yesterday")
set terminal pngcairo enhanced size 1280,1024
set output '/tmp/'.date.'-adsb.png'
set datafile separator " "
set title 'Message rate compared to aircraft seen'
set xlabel 'Aircraft'
set ylabel 'Messages rate /s'
set grid xtics ytics
f(x) = c*x/sqrt(d+x**2) + a*x**2 +b*x
c=4000
d=7000
a=0.05
b=-20
fit f(x) '/tmp/'.date.'-scatter' using 1:($2+$3) via a,b,c,d
plot '/tmp/'.date.'-scatter' using 1:($2+$3), f(x) notitle
EOF

sudo cp /tmp/$(date -I --date=yesterday)-adsb.png /run/dump1090-fa/graph.png
