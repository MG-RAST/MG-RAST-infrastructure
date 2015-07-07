#!/bin/bash
set -x
set -e

lvm vgremove --force vg01
# lvm lvdisplay
# sudo partprobe
sleep 3

for device in /dev/sda /dev/sdb ; do 
 dd if=/dev/zero of=${device} bs=1M count=1 ;
 # wipe last megabyte to get rid of RAID
 # 2048 is 1M/512bytes (getsz returns nuber of 512blocks)
 dd if=/dev/zero of=${device} bs=512 count=2048 seek=$((`blockdev --getsz ${device}` - 2048)) ;
done
sleep 2

# seems to require reboot here, because resource is busy. not sure where that comes from
