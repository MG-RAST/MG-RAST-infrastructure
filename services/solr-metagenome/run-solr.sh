#!/bin/sh -e

# this script runs solr in foreground

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

/opt/solr/bin/solr start -p $SOLR_PORT -a "-XX:OnOutOfMemoryError=\"$BIN/kill_solr_by_port.sh\"" -f
