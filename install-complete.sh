#!/bin/bash
clear
echo "--------------"
echo "Bundle install for dump1090-fa by wiedehopf"
echo "--------------"


bash -c "$(wget -q -O - https://raw.githubusercontent.com/wiedehopf/adsb-wiki/master/install-dump1090-fa.sh)" 2>&1 | sed -e 's?://?  ?' -e 's?ttp??' -e 's/@/_at_/'
bash -c "$(wget -q -O - https://raw.githubusercontent.com/wiedehopf/adsb-wiki/master/dump1090-fa-autogain.sh)" 2>&1 | sed -e 's?://?  ?' -e 's?ttp??' -e 's/@/_at_/'
bash -c "$(wget -q -O - https://raw.githubusercontent.com/wiedehopf/dump1090-retro-html/master/install.sh)" 2>&1 | sed -e 's?://?  ?' -e 's?ttp??' -e 's/@/_at_/'
