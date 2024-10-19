#!/usr/bin/env bash

set -e
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR

modprobe zram

function make_zram() {
    NAME="$1"
    ALGO="$2"
    MOUNTPOINT="$3"
    DEV=/dev/$NAME

    umount "$MOUNTPOINT" &>/dev/null || true

    if ! [[ -e $DEV ]]; then
        cat /sys/class/zram-control/hot_add
    fi

    # reset the device to ensure we can set the parameters
    for i in {1..9}; do
        if echo 1 > "/sys/block/$NAME/reset"; then
            break
        fi
        sleep 1
    done

    # https://github.com/lz4/lz4?tab=readme-ov-file#benchmarks
    # Core i7-9700K single thread
    # Compressor            Ratio   Compression Decompression
    # LZ4 default (v1.9.0)  2.101   780 MB/s    4970 MB/s
    # Zstandard 1.4.0 -1    2.883   515 MB/s    1380 MB/s
    #
    # on a pi4, lz4 in compression has even higher relative speed over zstd
    # use zstd for now even though it's slower
    #echo lz4 > "/sys/block/$NAME/comp_algorithm"
    echo "$ALGO" > "/sys/block/$NAME/comp_algorithm"

    # use 1/4 of memory
    use=$(( $(grep -e MemTotal /proc/meminfo | tr -s ' ' | cut -d' ' -f2) / 4 ))

    # use at least 256M for systems with small memory
    min=$(( 256 * 1024 ))

    if (( use < min )); then
        size=$min
    else
        size=$use
    fi

    # zram maximum memory usage
    echo $(( size ))K > "/sys/block/$NAME/mem_limit"

    # disk size
    # let's make this 3x the memory limit in case we get good compression
    echo $(( 4 * size ))K > "/sys/block/$NAME/disksize"

    mkfs.ext2 "$DEV" &>/dev/null
    mkdir -p "$MOUNTPOINT"
    mount "$DEV" "$MOUNTPOINT"
}

function reset_cache() {
    sync
    #echo 3 > /proc/sys/vm/drop_caches
}

function test_zram_algo() {
    ALGO="$1"
    SIZE=100
    MP=/test_zram_algo
    ZRAM=zram1
    make_zram $ZRAM "$ALGO" $MP

    ZF=/$MP/testfile

    reset_cache

    echo
    echo "$ALGO $ALGO $ALGO $ALGO $ALGO $ALGO $ALGO $ALGO $ALGO $ALGO $ALGO $ALGO $ALGO $ALGO $ALGO $ALGO $ALGO $ALGO $ALGO $ALGO"
    echo -n "from /run to zram: "
    dd if=$TF of=$ZF bs=1M oflag=dsync 2>&1 | grep -v records

    reset_cache
    echo 1 > /proc/sys/vm/drop_caches
    sleep 1

    echo -n "from zram to /run: "
    dd if=$ZF of=$TF bs=1M oflag=dsync 2>&1 | grep -v records

    reset_cache

    zramctl | grep $ZRAM | awk '{ print "uncompressed: ", $4, " compressed: ",$5 }'

    umount $MP || true
    echo 1 > "/sys/block/$ZRAM/reset"

}

function test_algos() {
    test_zram_algo zstd
    test_zram_algo lz4
    test_zram_algo lzo
    #test_zram_algo lzo-rle
}

DF=/tmp/zram_td_100.zst
if ! [[ -f $DF ]]; then
    wget -O $DF https://github.com/wiedehopf/adsb-wiki/releases/download/compression_test/zram_td_100.zst
fi

TF=/run/zram_test_file

echo
echo "Testing using first 100MB of chrome binary:"

zstd -f -d $DF -o $TF -q

test_algos

if [[ $1 == all ]]; then
    echo
    echo "Testing using 100MB random data"

    dd if=/dev/urandom of=$TF bs=1M count=100 status=none

    test_algos

    echo
    echo "Testing using 100MB zeroes"

    dd if=/dev/zero of=$TF bs=1M count=100 status=none

    test_algos
fi

rm -f "$TF"
