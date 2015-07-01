#!/bin/bash

BASE_DIR=$1

CASS_VERSION="2.1.7"
CASS_TARBALL="apache-cassandra-${CASS_VERSION}-bin.tar.gz"
CASS_URL="http://psg.mtu.edu/pub/apache/cassandra/${CASS_VERSION}/${CASS_TARBALL}"

AGENT_VERSION="5.1.3"
AGENT_TARBALL="datastax-agent-${AGENT_VERSION}.tar.gz"
AGENT_URL="http://downloads.datastax.com/community/${AGENT_TARBALL}"

cd /
set -e
set -x

mkdir -p $BASE_DIR

curl -s ${CASS_URL} | tar -zxvf - -C $BASE_DIR
ln -s $BASE_DIR/apache-cassandra-$CASS_VERSION $BASE_DIR/cassandra

curl -s ${AGENT_URL} | tar -zxvf - -C $BASE_DIR
ln -s $BASE_DIR/datastax-agent-$AGENT_VERSION $BASE_DIR/agent

exit 0