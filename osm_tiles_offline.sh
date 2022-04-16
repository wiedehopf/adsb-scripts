#!/bin/bash

set -e
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR

IPATH=/usr/local/share/osm_tiles_offline

mkdir -p "$IPATH"
cd "$IPATH"

F=osm_tiles_0_9.tar.gz
wget -O $F https://www.adsbexchange.com/myip/downloads/$F
tar --overwrite -x -f $F
rm -f $F
