#!/bin/bash


set -x


if [ ${DOCKERVERSION}x = x ] ; then
  echo "Variable DOCKERVERSION is not set"
  exit 1 
fi

rm -f /usr/bin/docker

# "/docker" is a host directory, use it as cache
if [ ! -e /docker/docker-${DOCKERVERSION} ] ; then
   cd /docker
   #curl -fsSL https://get.docker.com/builds/Linux/x86_64/docker-${DOCKERVERSION}.tgz | tar --strip-components=1 -xvz docker/docker
   curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKERVERSION}.tgz | tar --strip-components=1 -xvz docker/docker
   if [ ! -e /docker/docker ] ; then
     #old url
     curl -fsSL https://get.docker.com/builds/Linux/x86_64/docker-${DOCKERVERSION}.tgz | tar --strip-components=1 -xvz docker/docker
   fi
   mv /docker/docker /docker/docker-${DOCKERVERSION}
fi
#if [ ! -e /docker/docker-${DOCKERVERSION} ] ; then
#  curl -o /docker/docker-${DOCKERVERSION} https://get.docker.com/builds/Linux/x86_64/docker-${DOCKERVERSION}
#fi

chmod +x /docker/docker-${DOCKERVERSION}
ln -s /docker/docker-${DOCKERVERSION} /usr/bin/docker


set -e
# test to make sure client and server version of docker are the same
/usr/bin/docker version
set +e

export ETCD_ENDPOINT=$(route|grep default|awk '{print $2}'):4001
# usually => export ETCD_ENDPOINT=172.17.42.1:4001
export CONF_DIR="/config/"
export TOML_FILE="/config/conf.d/nginx.toml"
export CONFD_ARGS="-node ${ETCD_ENDPOINT} -confdir=${CONF_DIR} -config-file=${TOML_FILE}"

mkdir -p /etc/nginx/sites-enabled/

# the first call often fails
confd -onetime ${CONFD_ARGS}
sleep 1
# start nginx

set -e

#for interval polling:  -watch=false -interval=5
confd -watch ${CONFD_ARGS}

