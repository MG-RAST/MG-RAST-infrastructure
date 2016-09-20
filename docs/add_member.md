## Add new member or proxy to etcd cluster

(note: these instructions more a collection of commands I have used, they are not yet in the right order necessarily. I will improve that in the future.)

```bash
source /etc/environment
export discovery_token=$(cat /run/systemd/system/etcd2.service.d/20-cloudinit.conf | grep ETCD_DISCOVERY | grep -o "[0-9a-f]\{32\}")
export discovery_url=https://discovery.etcd.io/${discovery_token}
export member_name=${ETCD_NAME}
export member_id=$(curl ${discovery_url} | grep -o "[0-9a-z]*\",\"value\":\"${member_name}" | grep -o "^[0-9a-z]*") # risky JSON parsing!
export member_ip=${COREOS_PRIVATE_IPV4}

# verify results
echo -e \
"export discovery_token=${discovery_token}\n"\
"export discovery_url=${discovery_url}\n"\
"export member_name=${member_name}\n"\
"export member_id=${member_id}\n"\
"export member_ip=${member_ip}\n"

```

delete data on new member
```bash
sudo systemctl stop etcd2
rm -rf /media/ephemeral/etcd2/*

curl ${discovery_url}/${member_id} -X DELETE
```

On an active cluster machine (not for proxy mode !)
```bash
etcdctl member remove ${member_id} # if this fails, your member might have been a proxy in fact.

etcdctl member add ${member_name} http://${member_ip}:2380
```
copy ETCD_NAME and ETCD_INITIAL_CLUSTER !



The value for ETCD_INITIAL_CLUSTER is given to you when you add a new member. If you do not get the value, you can build it manually:  
(make sure the new member is in ETCD_INITIAL_CLUSTER!)
```bash
GREP_OBJ=$(for i in $(etcdctl member list | grep -o "140.221.76.[0-9]*" | uniq) ; do echo -n $i ; echo -n "\|" ; done)

export ETCD_INITIAL_CLUSTER=$(fleetctl list-machines -no-legend  | grep "${GREP_OBJ}${member_ip}" | sed  's/.*\(140[0-9\.]*\).*\(node_[0-9a-z:]*\).*/\2=http:\/\/\1:2380/g' | tr '\n' ',')
echo "export ETCD_INITIAL_CLUSTER=\"${ETCD_INITIAL_CLUSTER}${member_name}=http://${member_ip}:2380\""
```

Create file on new member:
```bash
vi etcd-add.sh
```
and paste content:
```bash
#!/bin/bash
### INSERT ETCD_INITIAL_CLUSTER HERE


source /etc/environment
export discovery_token=$(cat /run/systemd/system/etcd2.service.d/20-cloudinit.conf | grep ETCD_DISCOVERY | grep -o "[0-9a-f]\{32\}")
export discovery_url=https://discovery.etcd.io/${discovery_token}
export member_name=${ETCD_NAME}
export member_id=$(curl ${discovery_url} | grep -o "[0-9a-z]*\",\"value\":\"${member_name}" | grep -o "^[0-9a-z]*") # risky JSON parsing!
export member_ip=${COREOS_PRIVATE_IPV4}

export ETCD_INITIAL_CLUSTER_STATE="existing"
export ETCD_ADVERTISE_CLIENT_URLS=http://${member_ip}:2379
export ETCD_DATA_DIR=/media/ephemeral/etcd2/${discovery_token}
export ETCD_DISCOVERY=""
export ETCD_ELECTION_TIMEOUT=1250
export ETCD_HEARTBEAT_INTERVAL=250
export ETCD_INITIAL_ADVERTISE_PEER_URLS=http://${member_ip}:2380
export ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379,http://0.0.0.0:4001
export ETCD_LISTEN_PEER_URLS=http://${member_ip}:2380,http://${member_ip}:7001
export ETCD_NAME=${member_name}
/usr/bin/etcd2 --initial-cluster ${ETCD_INITIAL_CLUSTER} --initial-cluster-state existing
# ***PROXY *** Add this flag to the above command to activate as an proxy: --proxy on

```

Let new node join the cluster
```bash
chmod +x etcd-add.sh 

chown etcd:etcd  /media/ephemeral/etcd2/
chown etcd:etcd  /media/ephemeral/etcd2/${discovery_token}

chmod +x .
sudo -u etcd ./etcd-add.sh 
```

Once node joins, stop node and do normal 
```bash
systemctl start etcd2
```

# proxy mode
The above script will fail in proxy mode ("etcdmain: failed to notify systemd for readiness: No socket"), but it generates the required files. Just run "systemctl start etcd2".
