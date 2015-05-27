#!/usr/bin/env bash

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

echoerr() { cat <<< "$@" 1>&2; }

SOLR_PID=`ps auxww | grep start.jar | grep $SOLR_PORT | grep -v grep | awk '{print $2}' | sort -r`
if [ -z "$SOLR_PID" ]; then
  echoerr "Couldn't find Solr process running on port $SOLR_PORT!"
  exit
fi
NOW=$(date +"%F_%H_%M_%S")
echoerr "$NOW: Running OOM killer script for process $SOLR_PID for Solr on port $SOLR_PORT"
kill -9 $SOLR_PID
NOW=$(date +"%F_%H_%M_%S")
echoerr "$NOW: Killed process $SOLR_PID"
