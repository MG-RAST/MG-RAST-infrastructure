#!/bin/bash
set -x


TARGET=/srv/www/html/coreos/

PUBLIC_KEYS=$(cat ${TARGET}keys.yaml| sed ':a;N;$!ba;s/\n/\\n/g')
DISCOVERY_TOKEN=$(cat ${TARGET}discovery_token.txt)
NETWORK_INTERFACE=enp2s0f0


# use template from local git repo or download
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

sed -e "s;%ssh_authorized_keys%;${PUBLIC_KEYS};g" -e "s;%network_interface%;${NETWORK_INTERFACE};g" -e "s;%discovery_token%;${DISCOVERY_TOKEN};g" ./cloud-config-pxe.yml.template > ${TARGET}cloud-config-pxe.yml