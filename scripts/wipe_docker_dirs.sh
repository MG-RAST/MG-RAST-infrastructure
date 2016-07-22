#!/bin/bash

# example:
# KEYFILE=~/.ssh/<key>.pem
# SSH_OPTIONS="-i ${KEYFILE} -oBatchMode=yes -oStrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
# for i in 5 10 11 14 20 21 ; do scp -i ${KEYFILE} -oBatchMode=yes -oStrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null wipe_docker_dirs.sh core@bio-worker${i}: ; done
# for i in 5 10 11 14 20 21 ; do ssh ${SSH_OPTIONS} -l core bio-worker${i} sudo ./wipe_docker_dirs.sh ; done

set -x

systemctl stop docker
sleep 1
for b in `ls /media/ephemeral/docker/btrfs/subvolumes/`; do btrfs subvolume delete /media/ephemeral/docker/btrfs/subvolumes/$b; done
rm -rf /media/ephemeral/docker/
systemctl start docker