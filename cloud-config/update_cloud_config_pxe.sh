#!/bin/bash
set -x
set -e


TARGET=/srv/www/html/coreos/

TEMPLATE_DIR=~/MG-RAST-infrastructure/cloud-config/
CONFIG=~/mgrast-config/

TEMPLATE=${TEMPLATE_DIR}cloud-config-pxe.yml.template

for i in ${TEMPLATE_DIR} ${CONFIG} ; do 
  cd ${i}
  git pull
done


# this strangely looking sed commands "sed ':a;N;$!ba;s/\n/\\n/g'" convert linebreaks into "\n" strings

PUBLIC_KEYS=$(cat ${CONFIG}cloud-config/keys.yaml| sed ':a;N;$!ba;s/\n/\\n/g')
DISCOVERY_TOKEN=$(cat ${CONFIG}cloud-config/discovery_token.txt)
NETWORK_INTERFACE=enp2s0f0
PRIVATE_KEY=$(sed 's/^/        /' ${CONFIG}ssh_key/mgrast_coreos.pem | sed ':a;N;$!ba;s/\n/\\n/g')




sed -e "s;%ssh_authorized_keys%;${PUBLIC_KEYS};g" -e "s;%network_interface%;${NETWORK_INTERFACE};g" -e "s;%discovery_token%;${DISCOVERY_TOKEN};g" -e "s;%config_private_ssh_key%;${PRIVATE_KEY};g" ${TEMPLATE} > ${TARGET}cloud-config-pxe.yml