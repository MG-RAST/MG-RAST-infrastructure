

This are instructions to create an mdadm RAID1 (mirror) with swap and btrfs partitions. First step is removal of any existing mdadm array or LVM ond the disks.


###Remove existing RAID

scripts/wipe_raid.sh



### Remove LVM
Example procedure (remove LVM, create RAID 1, create swap+data partitions):

scripts/wipe_lvm.sh

## Create RAID1 with swap+data partitions
scripts/create_raid1.sh

Filesystem will be created by cloud-config. But you can manually test you setup:
```bash
#/usr/sbin/mkswap /dev/md0p1
#/usr/sbin/mkfs.btrfs -f /dev/md0p2

/usr/sbin/swapon /dev/md0p1
/usr/bin/mkdir -p /media/ephemeral/
/usr/bin/mount -t btrfs /dev/md0p2 /media/ephemeral/
```


## Multiple machines example:
```bash
export MACHINES=`eval echo "{1..8} {10..11}"` ; echo ${MACHINES}
# test ssh
for i in ${MACHINES} ; do echo "$i: " ; ssh -o ConnectTimeout=1 -i ~/.ssh/wo_magellan_private_key.pem core@bio-worker${i} grep PRETTY /etc/os-release ; done
# copy wipe_lvm.sh
for i in ${MACHINES} ; do echo "$i: " ; scp -i ~/.ssh/wo_magellan_private_key.pem wipe_lvm.sh core@bio-worker${i}: ; done
# execute wipe_lvm.sh
for i in ${MACHINES} ; do echo "$i: " ; ssh -i ~/.ssh/wo_magellan_private_key.pem core@bio-worker${i} sudo ./wipe_lvm.sh ; done
#reboot
for i in ${MACHINES} ; do echo "$i: " ; ssh -i ~/.ssh/wo_magellan_private_key.pem core@bio-worker${i} sudo reboot ; done
#remove keys:
for i in ${MACHINES} ; do echo "$i: " ; ssh-keygen -f "/homes/wgerlach/.ssh/known_hosts" -R bio-worker${i} ; done
#test again ssh
for i in ${MACHINES} ; do echo "$i: " ; ssh -o ConnectTimeout=1 -i ~/.ssh/wo_magellan_private_key.pem core@bio-worker${i} grep PRETTY /etc/os-release ; done
#copy create_raid1.sh
for i in ${MACHINES} ; do echo "$i: " ; scp -i ~/.ssh/wo_magellan_private_key.pem create_raid1.sh core@bio-worker${i}: ; done
# execute create_raid1.sh
for i in ${MACHINES} ; do echo "$i: " ; ssh -i ~/.ssh/wo_magellan_private_key.pem core@bio-worker${i} sudo ./create_raid1.sh ; done
# reboot last time
for i in ${MACHINES} ; do echo "$i: " ; ssh -i ~/.ssh/wo_magellan_private_key.pem core@bio-worker${i} sudo reboot ; done
```
