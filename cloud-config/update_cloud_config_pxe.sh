#!/bin/bash
set -x
set -e

# execute this script in mgrast-config


TARGET=/srv/www/html/coreos/

PUBLIC_KEYS=$(cat cloud-config/keys.yaml| sed ':a;N;$!ba;s/\n/\\n/g')
DISCOVERY_TOKEN=$(cat cloud-config/discovery_token.txt)
NETWORK_INTERFACE=enp2s0f0
PRIVATE_KEY=$(sed 's/^/        /' ssh_key/mgrast_coreos.pem)


# use template from local git repo or download
set +e
git rev-parse --is-inside-work-tree > /dev/null 2>&1 
IS_GIT_DIR=$?
set -e



if [ ${IS_GIT_DIR} -eq 0 ] 
then
	git pull
else 
	rm -f cloud-config-pxe.yml.template
	wget --no-check-certificate https://raw.githubusercontent.com/MG-RAST/MG-RAST-infrastructure/master/cloud-config/cloud-config-pxe.yml.template 
fi

sed -e "s;%ssh_authorized_keys%;${PUBLIC_KEYS};g" -e "s;%network_interface%;${NETWORK_INTERFACE};g" -e "s;%discovery_token%;${DISCOVERY_TOKEN};g" -e "s;%config_private_ssh_key%;${PRIVATE_KEY};g" cloud-config/cloud-config-pxe.yml.template > ${TARGET}cloud-config-pxe.yml