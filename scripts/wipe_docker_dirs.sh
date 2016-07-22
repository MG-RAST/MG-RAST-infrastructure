#!/bin/bash

# example:
# alias coreos='ssh -i ~/.ssh/<key>.pem -oBatchMode=yes -oStrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -l core '
# for i in 5 10 11 14 20 21 ; do scp -i ~/.ssh/<key>.pem -oBatchMode=yes -oStrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null wipe_docker_dirs.sh core@bio-worker${i}: ; done
# for i in 5 10 11 14 20 21 ; do coreos bio-worker${i} sudo wipe_docker_dirs.sh ; done

set -x

systemctl stop docker
sleep 1
for b in `ls /media/ephemeral/docker/btrfs/subvolumes/`; do btrfs subvolume delete /media/ephemeral/docker/btrfs/subvolumes/$b; done
rm -rf /media/ephemeral/docker/
systemctl start docker