#!/bin/bash
set -x
set -e


# OSX: brew install gnu-sed --with-default-names # warning overwrites system sed !

UNAME=$(uname)

SED_CMD=sed

if [ "$UNAME" == "Darwin" ] ; then
  SED_CMD=gsed
fi

TARGET=/usr/share/nginx/html/coreos/

TEMPLATE_DIR=~/git/MG-RAST-infrastructure/cloud-config/
CONFIG=~/git/mgrast-config/

TEMPLATE=${TEMPLATE_DIR}cloud-config-pxe.yaml.template

DIR=`pwd`

for i in ${TEMPLATE_DIR} ${CONFIG} ; do 
  cd ${i}
  git pull
done

cd $DIR

# this strangely looking sed commands "sed ':a;N;$!ba;s/\n/\\n/g'" convert linebreaks into "\n" strings

PUBLIC_KEYS=$(cat ${CONFIG}cloud-config/keys.yaml| sed ':a;N;$!ba;s/\n/\\n/g')
DISCOVERY_TOKEN=$(cat ${CONFIG}cloud-config/discovery_token.txt)
NETWORK_INTERFACE=enp2s0f0
PRIVATE_KEY=$(sed 's/^/        /' ${CONFIG}ssh_key/mgrast_coreos.pem | sed ':a;N;$!ba;s/\n/\\n/g')




${SED_CMD} -e "s;%ssh_authorized_keys%;${PUBLIC_KEYS};g" -e "s;%network_interface%;${NETWORK_INTERFACE};g" -e "s;%discovery_token%;${DISCOVERY_TOKEN};g" -e "s;%config_private_ssh_key%;${PRIVATE_KEY};g" ${TEMPLATE} > cloud-config-pxe.yaml

set +x

echo "scp and execute on matchbox:"
echo "> scp cloud-config-pxe.yaml matchbox:~"
echo "> cp cloud-config-pxe.yaml ${TARGET}cloud-config-pxe.yaml"
echo "> chmod 664 ${TARGET}cloud-config-pxe.yaml"
