#!/bin/bash

# set default value
M5NR_VERSIONS="1 10"

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

if [ "$1" != "" ]; then
    M5NR_VERSIONS=$1
fi

for i in $M5NR_VERSIONS
do
    M5NR_VERSION=$i
    echo ""
    echo "M5NR_VERSION = $M5NR_VERSION"
    echo ""

    cp -av /opt/solr/server/solr/configsets/sample_techproducts_configs /opt/solr/server/solr/m5nr_${M5NR_VERSION}
    echo "name=m5nr_${M5NR_VERSION}" > /opt/solr/server/solr/m5nr_${M5NR_VERSION}/core.properties
    cp schema.xml /opt/solr/server/solr/m5nr_${M5NR_VERSION}/conf/schema.xml
    cp solr.in.sh /opt/solr/bin
    mkdir -p /mnt/m5nr_${M5NR_VERSION}/data
    tpage --define data_dir=/mnt/m5nr_${M5NR_VERSION}/data --define max_bool=100000 solrconfig.xml.tt > /opt/solr/server/solr/m5nr_${M5NR_VERSION}/conf/solrconfig.xml
done
exit 0;
