


Start MMS on bio-worker10

```bash
#execute as root


# get right version of docker-compose
mkdir -p /media/ephemeral/opt/
ln -s /media/ephemeral/opt/ /opt
mkdir -p /opt/bin/

DOCKER_COMPOSE_VERSION="1.19.0"

if [ ! -e /opt/bin/docker-compose-${DOCKER_COMPOSE_VERSION} ] ; then
  curl -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-Linux-x86_64 -o /opt/bin/docker-compose-${DOCKER_COMPOSE_VERSION}
  chmod +x /opt/bin/docker-compose-${DOCKER_COMPOSE_VERSION}
  rm -f /opt/bin/docker-compose
  ln -s /opt/bin/docker-compose-${DOCKER_COMPOSE_VERSION} /opt/bin/docker-compose
fi 


# get git repository
SERVICE_DIR="/media/ephemeral/mms/"
mkdir -p ~/.ssh/; if [ `ssh-keygen -F gitlab.cels.anl.gov | grep -v "^#" | wc -l` -eq "0" ]; then ssh-keyscan -H gitlab.cels.anl.gov >> ~/.ssh/known_hosts; fi
eval $(ssh-agent); ssh-add /etc/ssh/mgrast_coreos.pem; rm -rf ${SERVICE_DIR}/mgrast-config; cd ${SERVICE_DIR}; git clone git@gitlab.cels.anl.gov:MG-RAST/mgrast-config.git


cd /root/ ; git clone https://github.com/MG-RAST/MG-RAST-infrastructure.git
cd MG-RAST-infrastructure/services/mgrast-message-system

source ./init.sh

docker-compose up -d
```