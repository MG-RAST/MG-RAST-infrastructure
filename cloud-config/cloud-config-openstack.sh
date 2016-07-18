#!/bin/bash

# template requires discovery token
# this hack below is needed to get IP address
# tested on magellan
 
until ! [[ -z "${COREOS_PRIVATE_IPV4}" ]]; do
    COREOS_PUBLIC_IPV4=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)
    COREOS_PRIVATE_IPV4=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
    echo "COREOS_PUBLIC_IPV4=${COREOS_PUBLIC_IPV4}" > /etc/environment
    echo "COREOS_PRIVATE_IPV4=${COREOS_PRIVATE_IPV4}" >> /etc/environment
done

until ! [[ -z "${INSTANCE_TYPE}" ]]; do
    INSTANCE_TYPE=$(curl http://169.254.169.254/latest/meta-data/instance-type)
    echo "INSTANCE_TYPE=${INSTANCE_TYPE}" >> /etc/environment
done

HOSTNAME=`echo $HOSTNAME | cut -f1 -d'.'`
VERSION_ID=`grep VERSION_ID /etc/os-release | grep -o '[0-9]*\.[0-9]*\.[0-9]*'`
RAM_GB=`awk '/MemTotal/ {printf( "%.0f\n", $2 / (1024*1024) )}' /proc/meminfo`
CORES=`nproc --all`

echo "HOSTNAME=${HOSTNAME}" >> /etc/environment
echo "CoreOS=${VERSION_ID}" >> /etc/environment
echo "RAM_GB=${RAM_GB}" >> /etc/environment
echo "CORES=${CORES}" >> /etc/environment

METADATA="HOSTNAME=${HOSTNAME},INSTANCE_TYPE=${INSTANCE_TYPE},RAM_GB=${RAM_GB},CORES=${CORES},CoreOS=${VERSION_ID}"
source /etc/environment

MOUNT_POINT="/mnt"
mkdir -p ${MOUNT_POINT}

EPHEMERAL="`curl -s -f -m 20 http://169.254.169.254/latest/meta-data/block-device-mapping/ephemeral0`"
if [ -z "${EPHEMERAL}" ]; then
	# workaround for a bug in EEE 2
	EPHEMERAL="`curl -s -f -m 20 http://169.254.169.254/latest/meta-data/block-device-mapping/ephemeral`"
fi
if [ ! -z "${EPHEMERAL}" ]; then
MOUNTUNIT=$(cat <<EOF
   - name: media-ephemeral.mount
     command: start
     content: |
       [Mount]
       What=${EPHEMERAL}
       Where=/media/ephemeral
       Type=ext3
EOF
)
fi

 
cat << 'EOF' > /tmp/user_data.yml 
#cloud-config
coreos: 
 etcd2:
   # name this is required because pxe-booting would create new ETCD instance names on boot.
   name: ${HOSTNAME}
   # generate a new token for each unique cluster from https://discovery.etcd.io/new?size=3
   discovery: "https://discovery.etcd.io/%discovery_token%"
   # multi-region and multi-cloud deployments need to use $public_ipv4
   advertise-client-urls: "http://${COREOS_PRIVATE_IPV4}:2379"
   initial-advertise-peer-urls: "http://${COREOS_PRIVATE_IPV4}:2380"
   # listen on both the official ports and the legacy ports
   # legacy ports can be omitted if your application doesn't depend on them
   listen-client-urls: "http://${COREOS_PRIVATE_IPV4}:2379,http:/127.0.0.1:2379"
   listen-peer-urls: "http://${COREOS_PRIVATE_IPV4}:2380"
   #discovery: https://discovery.etcd.io/<token>
   #addr: \$private_ipv4:4001
   #peer-addr: \$private_ipv4:7001
 fleet:
   public-ip: ${COREOS_PRIVATE_IPV4}
   metadata: ${METADATA}
 units:
   - name: etcd.service
     command: start
   - name: fleet.service
     command: start
   - name: settimezone.service
     command: start
     content: |
       [Unit]
       Description=Set the timezone

       [Service]
       ExecStart=/usr/bin/timedatectl set-timezone America/Chicago
       RemainAfterExit=yes
       Type=oneshot
${MOUNTUNIT}
#ssh_authorized_keys:
#  # include one or more SSH public keys
#  - <public ssh key>
EOF
 
sudo coreos-cloudinit --from-file=/tmp/user_data.yml
