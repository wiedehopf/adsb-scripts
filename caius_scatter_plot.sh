#!/bin/bash

# Fetch daily data from rrds

date=$(date -I --date=yesterday)
echo "Processing RRD data"


rrdtool fetch /var/lib/collectd/rrd/localhost/dump1090-localhost/dump1090_messages-local_accepted.rrd AVERAGE -s end-7days -e midnight today -r 3m -a > /tmp/messages_l
rrdtool fetch /var/lib/collectd/rrd/localhost/dump1090-localhost/dump1090_messages-remote_accepted.rrd AVERAGE -s end-7days -e midnight today -r 3m -a > /tmp/messages_r
rrdtool fetch /var/lib/collectd/rrd/localhost/dump1090-localhost/dump1090_range-max_range.rrd MAX -s end-7days -e midnight today -r 3m -a > /tmp/range
rrdtool fetch /var/lib/collectd/rrd/localhost/dump1090-localhost/dump1090_aircraft-recent.rrd AVERAGE -s end-7days -e midnight today -r 3m -a > /tmp/aircraft


# Remove headers and extraneous character :


sed -i -e 's/://' -e 's/\,/\./g' /tmp/messages_l
sed -i -e 's/://' -e 's/\,/\./g' /tmp/messages_r
sed -i -e 's/://' -e 's/\,/\./g' /tmp/range
sed -i -e 's/://' -e 's/\,/\./g' /tmp/aircraft


sed -i -e '1d;2d' /tmp/messages_l
sed -i -e '1d;2d' /tmp/messages_r
sed -i -e '1d;2d' /tmp/range
sed -i -e '1d;2d' /tmp/aircraft

# Combine files to create space separated data file for use by gnuplot


join -o 1.1 1.2 2.2 /tmp/range /tmp/messages_l > /tmp/tmp
join -o 1.1 1.2 1.3 2.2 /tmp/tmp /tmp/messages_r > /tmp/tmp1
join -o 1.2 1.3 1.4 2.2 /tmp/tmp1 /tmp/aircraft > /tmp/$date-ranges

cd /tmp

echo "Generating plot"

gnuplot /dev/stdin <<"EOF"
date = system("date -I --date=yesterday")
date1 = system("date -I --date=-7days")
gain = system("awk '{for(i=1;i<=NF;i++)if($i~/--gain/)print $(i+1)}' /etc/default/dump1090-fa")
set terminal pngcairo enhanced size 1900,900
set output 'range.png'
set title 'Receiver performance '.date1.' to '.date.' Gain: '.gain
set xlabel 'Aircraft'
set ylabel 'Message rate'
set cblabel 'Range nm'
set grid xtics ytics
f(x) = c*x/sqrt(d+x**2) + a*x**2 +b*x
c=4000
d=7000
a=0.05
b=-20
fit f(x) '/tmp/'.date.'-ranges' using ($4):($2+$3) via a,b,c,d
stats '/tmp/'.date.'-ranges' using ($1/1852) name "Range"
lb = (Range_mean - Range_stddev*2)
ub = (Range_mean + Range_stddev*2)
set cbrange [lb:ub]
plot    '/tmp/'.date.'-ranges' using ($4):($2+$3):($1/1852) with points lt palette notitle, f(x) lt rgb "black" notitle
EOF

echo "Moving plot"

sudo cp /tmp/range.png /run/dump1090-fa/graph.png
