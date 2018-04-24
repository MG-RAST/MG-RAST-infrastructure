#!/bin/bash
set -x



for raid in $(cat /proc/mdstat | grep active | cut -f 1 -d ' ') ; do
  echo "found raid: $raid"  
  
  
  # TODO unmount
  
  PARTITIONS=$(mdadm -D /dev/${raid} | grep -o "/dev/sd[a-z][0-9]" | tr "\n" " ")
  DEVICES=$(mdadm -D /dev/${raid} | grep -o "/dev/sd[a-z]" | tr "\n" " ")
 
 
   #swapoff /dev/${raid}p1
 
  mdadm --stop /dev/${raid}
  
  mdadm --remove /dev/${raid}
  
  mdadm --zero-superblock ${PARTITIONS}
  mdadm --zero-superblock ${DEVICES}
  
  for device in ${DEVICES} ; do 
    echo -e -n "o\\ny\\nw\ny\\n" | gdisk ${device}
    sleep 2
  done



done



