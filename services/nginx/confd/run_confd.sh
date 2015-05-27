#!/bin/bash


set -x

set -e
# test to make sure client and server version of docker are the same
/usr/bin/docker version
set +e

export ETCD_ENDPOINT=$(route|grep default|awk '{print $2}'):4001
# usually => export ETCD_ENDPOINT=172.17.42.1:4001
export CONF_DIR="/MG-RAST-infrastructure/services/nginx/confd"
export TOML_FILE="/MG-RAST-infrastructure/services/nginx/confd/conf.d/nginx.toml"
export CONFD_ARGS="-node ${ETCD_ENDPOINT} -confdir=${CONF_DIR} -config-file=${TOML_FILE}"

mkdir -p /etc/nginx/sites-enabled/

# the first call often fails
confd -onetime ${CONFD_ARGS}
sleep 1
# start nginx

set -e

#for interval polling:  -watch=false -interval=5
confd -watch ${CONFD_ARGS}


# rund in another container now
#nginx -c /Skycore/services/nginx/nginx.conf
