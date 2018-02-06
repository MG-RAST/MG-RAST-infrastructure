#!/bin/bash

set -e

CURDIR=`pwd`

for service in event-loader mms-email service-checker service-monitor ; do
  echo "building service ${service} ..."
  cd ${CURDIR}/${service}
  set -x
  docker build -t mgrast/${service} .
  set +x
done


echo "done"
echo "----------------------------"



for service in event-loader mms-email service-checker service-monitor ; do
  echo "docker push mgrast/${service}"
done

echo "---------"

for service in event-loader mms-email service-checker service-monitor ; do
  echo "docker pull mgrast/${service}"
done