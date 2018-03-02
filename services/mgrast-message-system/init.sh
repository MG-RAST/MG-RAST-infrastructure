
#!/bin/bash


if [[ $_ == $0 ]]; then
  echo "Error: please use command \"source ./init.sh\""
  exit 1
fi


mkdir -p /media/ephermeral/opt/

if [ ! -h  /opt ]; then
    ln -s /media/ephermeral/opt/ /opt
fi

mkdir -p /opt/bin/

DOCKERVERSION=$(docker -v | grep -o "[0-9\.]*\.[0-9\.a-z-]*")
echo "detected DOCKERVERSION=${DOCKERVERSION}"

export DOCKER_BINARY=/opt/bin/docker

if [ ! -e ${DOCKER_BINARY}-${DOCKERVERSION} ] ; then
   cd /tmp/
   #curl -fsSL https://get.docker.com/builds/Linux/x86_64/docker-${DOCKERVERSION}.tgz | tar --strip-components=1 -xvz docker/docker
   curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKERVERSION}.tgz | tar --strip-components=1 -xvz docker/docker
   if [ ! -e docker ] ; then
     #old url
     curl -fsSL https://get.docker.com/builds/Linux/x86_64/docker-${DOCKERVERSION}.tgz | tar --strip-components=1 -xvz docker/docker
   fi
   mv ./docker ${DOCKER_BINARY}-${DOCKERVERSION}
   chmod +x ${DOCKER_BINARY}-${DOCKERVERSION}
   rm -f ${DOCKER_BINARY}
   ln -s ${DOCKER_BINARY}-${DOCKERVERSION} ${DOCKER_BINARY}
fi

export SERVICE_DIR="/media/ephemeral/mms/"

export MMS_CONFIG_FILE=${SERVICE_DIR}/mgrast-config/services/mms/config.yml
export RABBITMQ_DEFAULT_USER=$(grep -A 2 "^rabbitmq:" ${MMS_CONFIG_FILE} | grep " user:" | awk '{print$2}')
export RABBITMQ_DEFAULT_PASS=$(grep -A 2 "^rabbitmq:" ${MMS_CONFIG_FILE} | grep " password:" | awk '{print$2}')
export MYSQL_ROOT_PASSWORD=$(grep -A 6 "^mysql:" ${MMS_CONFIG_FILE} | grep " root_password:" | awk '{print$2}')
export MYSQL_USER=$(grep -A 6 "^mysql:" ${MMS_CONFIG_FILE} | grep " user:" | awk '{print$2}')
export MYSQL_PASSWORD=$(grep -A 6 "^mysql:" ${MMS_CONFIG_FILE} | grep " root_password:" | awk '{print$2}')

