#!/bin/bash
umask 022
renice 10 $$
clear
echo "--------------"
echo "Bundle install for dump1090-fa by wiedehopf"
echo "--------------"


bash -c "$(wget -q -O - https://raw.githubusercontent.com/wiedehopf/adsb-scripts/master/install-dump1090-fa.sh)"
bash -c "$(wget -q -O - https://raw.githubusercontent.com/wiedehopf/adsb-scripts/master/dump1090-fa-autogain.sh)"
bash -c "$(wget -q -O - https://raw.githubusercontent.com/wiedehopf/dump1090-retro-html/master/install.sh)"
bash -c "$(wget -q -O - https://raw.githubusercontent.com/wiedehopf/tar1090/master/install.sh)"
