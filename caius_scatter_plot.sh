#!/bin/bash

# Fetch daily data from rrds

date=$(date -I --date=yesterday)
echo "Processing RRD data"


rrdtool fetch /var/lib/collectd/rrd/localhost/dump1090-localhost/dump1090_messages-local_accepted.rrd AVERAGE -s end-7days -e midnight today -r 3m -a > /tmp/messages_l
rrdtool fetch /var/lib/collectd/rrd/localhost/dump1090-localhost/dump1090_messages-remote_accepted.rrd AVERAGE -s end-7days -e midnight today -r 3m -a > /tmp/messages_r
rrdtool fetch /var/lib/collectd/rrd/localhost/dump1090-localhost/dump1090_range-max_range.rrd MAX -s end-7days -e midnight today -r 3m -a > /tmp/range
rrdtool fetch /var/lib/collectd/rrd/localhost/dump1090-localhost/dump1090_aircraft-recent.rrd AVERAGE -s end-7days -e midnight today -r 3m -a > /tmp/aircraft


# Remove headers and extraneous :


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
set fit prescale

f(x) = 3000*c*x/sqrt(6000*d+x**2) + a/20*x**2 - 10*b*x
c=1
d=1
a=1
b=1
fit f(x) '/tmp/'.date.'-ranges' using ($4):($2+$3) via c,d
fit f(x) '/tmp/'.date.'-ranges' using ($4):($2+$3) via a,b,c,d
stats '/tmp/'.date.'-ranges' using ($1/1852) name "Range" noout
stats '/tmp/'.date.'-ranges' using ($2+$3) name "Messages" noout
stats '/tmp/'.date.'-ranges' using ($4) name "Aircraft" noout

lb = (Range_mean - Range_stddev*2)
ub = (Range_mean + Range_stddev*2)


set multiplot layout 1,4 title 'Receiver performance '.date1.' to '.date.'      Dump1090-fa gain: '.gain

set size 0.7,0.95
set xlabel 'Aircraft'
set ylabel 'Message rate'
set cblabel 'Range nm'
set grid xtics ytics
set cbrange [lb:ub]
set label 1 sprintf("Peak range = %3.2f",Range_max) right at graph 0.85,graph 0.4
set label 2 sprintf("Mean Maximum range = %3.2f",Range_mean) right at graph 0.85,0.38
set label 3 sprintf("Median Maximum range = %3.2f",Range_median) right at graph 0.85,0.36
set label 4 sprintf("Peak Message rate = %3.2f",Messages_max) right at graph 0.85,0.3
set label 5 sprintf("Mean Message rate = %3.2f",Messages_mean) right at graph 0.85,0.28
set label 6 sprintf("Median Message rate = %3.2f",Messages_median) right at graph 0.85,0.26
set label 7 sprintf("Peak Aircraft = %3.2f",Aircraft_max) right at graph 0.85,0.2
set label 8 sprintf("Mean Aircraft = %3.2f",Aircraft_mean) right at graph 0.85,0.18
set label 9 sprintf("Median Aircraft = %3.2f",Aircraft_median) right at graph 0.85,0.16

plot    '/tmp/'.date.'-ranges' using ($4):($2+$3):($1/1852) with points lt palette notitle, f(x) lt rgb "black" notitle

unset label 1
unset label 2
unset label 3
unset label 4
unset label 5
unset label 6
unset label 7
unset label 8
unset label 9
unset xlabel
unset xtics
set size 0.1,0.95
set origin 0.7,0
set ylabel 'Range'
set style fill solid 0.5 border -1
set style boxplot outliers pointtype 7
set style data boxplot
set pointsize 0.5
plot '/tmp/'.date.'-ranges' using (1):($1/1852) notitle

unset xlabel
unset xtics
set size 0.1,0.95
set origin 0.8,0
set ylabel 'Messages'
set style fill solid 0.5 border -1
set style boxplot outliers pointtype 7
set style data boxplot
set pointsize 0.5
plot '/tmp/'.date.'-ranges' using (1):($2+$3) notitle

unset xlabel
unset xtics
set size 0.1,0.95
set origin 0.9,0
set ylabel 'Aircraft'
set style fill solid 0.5 border -1
set style boxplot outliers pointtype 7
set style data boxplot
set pointsize 0.5
plot '/tmp/'.date.'-ranges' using (1):($4) notitle

unset multiplot


EOF

echo "Moving plot"

sudo cp /tmp/range.png /run/dump1090-fa/graph.png
