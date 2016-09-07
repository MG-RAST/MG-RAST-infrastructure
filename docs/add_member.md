## Add new member to etcd cluster


```bash
export member_id=
export member_name=
export member_ip=
export discovery_token=
export discovery_url=https://discovery.etcd.io/${discovery_token}
```


```bash
etcdctl member remove ${member_id}
etcdctl member add ${member_name} http://${member_ip}:2380
```

delete data
```bash
sudo systemctl stop etcd2
rm -rf /media/ephemeral/etcd2/*

curl ${discovery_url}/${member_id} -X DELETE
```

make sure the new member is in ETCD_INITIAL_CLUSTER!

```bash
GREP_OBJ=$(for i in $(etcdctl member list | grep -o "140.221.76.[0-9]*" | uniq) ; do echo -n $i ; echo -n "\|" ; done)

export ETCD_INITIAL_CLUSTER=$(fleetctl list-machines -no-legend  | grep "${GREP_OBJ}${member_ip}" | sed  's/.*\(140[0-9\.]*\).*\(node_[0-9a-z:]*\).*/\2=http:\/\/\1:2380/g' | tr '\n' ',')
```


vi etcd-test.sh
```bash
#!/bin/bash
export ETCD_INITIAL_CLUSTER_STATE="existing"
export ETCD_ADVERTISE_CLIENT_URLS=http://${member_ip}:2379
export ETCD_DATA_DIR=/media/ephemeral/etcd2/${discovery_token}
# (defined above) export ETCD_INITIAL_CLUSTER="..."
export ETCD_DISCOVERY=""
export ETCD_ELECTION_TIMEOUT=1250
export ETCD_HEARTBEAT_INTERVAL=250
export ETCD_INITIAL_ADVERTISE_PEER_URLS=http://${member_ip}:2380
export ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379,http://0.0.0.0:4001
export ETCD_LISTEN_PEER_URLS=http://${member_ip}:2380,http://${member_ip}:7001
export ETCD_NAME=${member_name}
/usr/bin/etcd2
```

Let new node join the cluster
```bash
chmod +x etcd-test.sh 

chown etcd:etcd  /media/ephemeral/etcd2/
chown etcd:etcd  /media/ephemeral/etcd2/${discovery_token}

sudo -u etcd ./etcd-test.sh 
```

Once node joins, stop node and do normal systemctl start etcd2.
