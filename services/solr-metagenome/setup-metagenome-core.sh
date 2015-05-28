#!/bin/bash

# set a default value
MG_VERSION="1"

# binary location from http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
BIN=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

DEP_CONFIG=${BIN}/deployment.cfg

if [ ! -e ${DEP_CONFIG} ]; then
    echo "source config file ${DEP_CONFIG} not found"
    exit 1
fi

source ${DEP_CONFIG}
set -e
set -x

echo ""
echo "MG_VERSION = $MG_VERSION"
echo ""

cp -av /opt/solr/server/solr/configsets/sample_techproducts_configs /opt/solr/server/solr/metagenome_${MG_VERSION}
echo "name=metagenome_${MG_VERSION}" > /opt/solr/server/solr/metagenome_${MG_VERSION}/core.properties
cp schema.xml /opt/solr/server/solr/metagenome_${MG_VERSION}/conf/schema.xml
cp solr.in.sh /opt/solr/bin
tpage --define data_dir=/mnt/metagenome_${MG_VERSION}/data --define max_bool=100000 solrconfig.xml.tt > /opt/solr/server/solr/metagenome_${MG_VERSION}/conf/solrconfig.xml
exit 0;
