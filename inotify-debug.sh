#!/bin/bash
set -e
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR

if ! command -v inotifywait || ! command -v s6wrap; then
    apt update
    apt install --no-install-recommends -y inotify-tools gcc libc6-dev make git

    cd /tmp
    rm -rf /tmp/s6wrap
    git clone https://github.com/wiedehopf/s6wrap
    cd s6wrap
    make
    cp -f s6wrap /usr/local/bin/
fi

echo 192000 > /proc/sys/fs/inotify/max_user_watches
nohup s6wrap --timestamps --args inotifywait -r -m /etc /opt /root /home /usr /lib /boot /var \
    | grep --line-buffered -F -v -e OPEN -e NOWRITE -e ACCESS -e /exclude_dir1 -e /exclude_dir2 \
    > /run/inotify.log 2>&1 &

echo "to view writes, use: tail -f -n 200 /run/inotify.log"
echo "to kill, use: pkill inotifywait"
