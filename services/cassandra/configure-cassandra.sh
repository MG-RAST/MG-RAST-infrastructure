#!/bin/bash

CONF_DIR=$1
BASE_DIR=$2

set -e
set -x

cd $BASE_DIR/agent/config
echo "stomp_interface: ${PUBLIC_IP}" > address.yaml

cd $BASE_DIR/cassandra/config
sed "s;[% public_ip %];$PUBLIC_IP;" $CONF_DIR/cassandra-env.sh > cassandra-env.sh
sed "s;[% public_ip %];$PUBLIC_IP;" $CONF_DIR/cassandra.yaml > cassandra.yaml
