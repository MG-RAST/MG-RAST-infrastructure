#!/bin/bash

set -e

CURDIR=`pwd`

# services in this repo
for service in event-loader mms-email service-checker service-monitor ; do
  echo "building service ${service} ..."
  cd ${CURDIR}/${service}
  set -x
  docker build -t mgrast/${service} .
  set +x
done

# services in other repos
for service in API-testing ; do
    echo "building service ${service} ..."
    cd ${CURDIR}/..
    set -x
    rm -rf ${service}
    git clone https://github.com/MG-RAST/${service}.git
    cd ${service}
    NAME=`echo "${service}" | tr '[:upper:]' '[:lower:]'`
    docker build -t mgrast/${NAME} .
    set +x
done

echo "done"
echo "----------------------------"



for service in event-loader mms-email service-checker service-monitor API-testing ; do
  echo "docker push mgrast/${service}"
done

echo "---------"

for service in event-loader mms-email service-checker service-monitor API-testing ; do
  echo "docker pull mgrast/${service}"
done