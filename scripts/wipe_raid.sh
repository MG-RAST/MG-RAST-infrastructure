#!/bin/bash
set -x

export DEVICES_STR="/dev/sd{a,b}"
export DEVICES=$(eval echo ${DEVICES_STR})
export PARTITIONS=$(eval echo ${DEVICES_STR}1)

export OLD_RAID=`cat /proc/mdstat | grep active | cut -f 1 -d ' ' | head -n 1`

umount /media/ephemeral/

if [ ! ${OLD_RAID}x = x ] ; then
  swapoff /dev/${OLD_RAID}p1
  mdadm --stop /dev/${OLD_RAID}
  mdadm --remove /dev/${OLD_RAID}
fi


mdadm --zero-superblock ${PARTITIONS}
mdadm --zero-superblock ${DEVICES}

for device in ${DEVICES} ; do 
  echo -e -n "o\\ny\\nw\ny\\n" | gdisk ${device}
  sleep 2
done
