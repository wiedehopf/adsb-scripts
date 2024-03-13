#!/bin/bash


# this needs to run as root
if [ "$(id -u)" != "0" ] ; then
	echo "this command requires superuser privileges - please run as sudo bash $0"
	exit 1
fi

for i in {1..8}; do
  dd if=/dev/urandom of=/run/testFile bs=1M count=25 status=none
  cp /run/testFile /tmp
  sync
  echo 3 > /proc/sys/vm/drop_caches
  if ! diff -q -s /run/testFile /tmp/testFile; then
      echo "------------------------------------------------------"
      echo "TEST FAILED! Please replace storage medium!"
      echo "------------------------------------------------------"
      exit 1
  fi
done
echo "------------------------------------------------------"
echo "Test completed OK! Storage probably fine :)"
echo "------------------------------------------------------"
