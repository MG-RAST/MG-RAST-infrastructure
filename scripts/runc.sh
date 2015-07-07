#!/bin/bash
set -e
echo "runc.sh <packages> <command>"
export PACKAGES=`echo -n $1 | tr ',' ' '`
shift 
export TMPDIR=`mktemp -d /tmp/runc.XXXXXXX`
set -x
echo -e "FROM ubuntu:14.04\nRUN apt-get update && apt-get -y install ${PACKAGES}\nWORKDIR /work\n" > ${TMPDIR}/Dockerfile
sudo docker rmi runc || echo ok
sudo docker build -t runc ${TMPDIR}/
rm -rf ${TMPDIR}
sudo docker run --rm -t -i -v `pwd`:/work runc $*


#example: runc.sh curl curl --help
#         runc.sh nano nano test.txt

