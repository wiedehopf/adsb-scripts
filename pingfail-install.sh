#!/bin/bash
umask 022

repo="https://github.com/wiedehopf/adsb-scripts"
ipath=/usr/local/share/adsb-scripts

if ! command -v git &>/dev/null
then
	apt-get update
	if ! apt-get install -y git
	then
		echo "Failed to install git, exiting!"
		exit 1
	fi
fi

mkdir -p $ipath

if git clone --depth 1 $repo $ipath/git 2>/dev/null || cd $ipath/git
then
	cd $ipath/git
	git checkout -f master
	git fetch
	git reset --hard origin/master
else
	echo "Download failed"
	exit 1
fi

cp pingfail.sh $ipath
cp pingfail.service /lib/systemd/system

systemctl enable pingfail
systemctl restart pingfail
