


Start MMS on bio-worker10

```bash

# get right version of docker-compose
curl -L https://github.com/docker/compose/releases/download/1.11.2/docker-compose-Linux-x86_64 -o ~/docker-compose
chmod +x ~/docker-compose

# get git repository
SERVICE_DIR="/media/ephemeral/mms/"
mkdir -p ~/.ssh/; if [ `ssh-keygen -F gitlab.cels.anl.gov | grep -v "^#" | wc -l` -eq "0" ]; then ssh-keyscan -H gitlab.cels.anl.gov >> ~/.ssh/known_hosts; fi
eval $(ssh-agent); ssh-add /etc/ssh/mgrast_coreos.pem; rm -rf ${SERVICE_DIR}/mgrast-config; cd ${SERVICE_DIR}; git clone git@gitlab.cels.anl.gov:MG-RAST/mgrast-config.git



cd ~/MG-RAST-infrastructure/services/mgrast-message-system

source ./init.sh

~/docker-compose up -d
```