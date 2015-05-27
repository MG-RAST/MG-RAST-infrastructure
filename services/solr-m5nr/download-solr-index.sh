#!/bin/bash

# set a default values
M5NR_VERSIONS="1 10"
SOLR_VERSION="5.0.0"
TARGET="/mnt"

# binary location from http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
BIN=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

DEP_CONFIG=${BIN}/deployment.cfg

if [ ! -e ${DEP_CONFIG} ]; then
    echo "source config file ${DEP_CONFIG} not found"
    exit 1
fi

set -e
set -x
source ${DEP_CONFIG}

for i in $M5NR_VERSIONS
do
    M5NR_VERSION=$i
    echo ""
    echo "SOLR_VERSION = $SOLR_VERSION"
    echo "TARGET = $TARGET"
    echo "M5NR_VERSION = $M5NR_VERSION"
    echo ""
    URL=''
    if [ "$M5NR_VERSION" == "10" ] && [ "$SOLR_VERSION" == "5.0.0" ]; then
        URL="http://shock.metagenomics.anl.gov/node/bd7bdbf9-dfba-4794-89e3-6f1bd0b5b9a8?download"
    elif [ "$M5NR_VERSION" == "1" ] && [ "$SOLR_VERSION" == "5.0.0" ]; then
        URL="http://shock.metagenomics.anl.gov/node/442aa062-6684-4cbd-ab1b-33b4d1ec5de6?download"
    fi  

    if [ "$URL" == "" ]; then
        echo "Data index not found for this solr/m5nr version.";
        exit 1;
    fi

    echo "URL = $URL";

    export INDEX_DIR=${TARGET}/m5nr_${M5NR_VERSION}/data/index/
    if [ ! -d ${INDEX_DIR} ]; then
        mkdir -p ${INDEX_DIR}
        curl -s "${URL}" | tar -zxvf - -C ${INDEX_DIR}
    fi
done
exit 0;
