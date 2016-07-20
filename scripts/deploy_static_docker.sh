#!/bin/bash


# This script will download a statically compiled docker binary, which can be easilt mounted into containers. 
# The docker binary that comes with CoreOS is currently not statically compiled.

set -e
set -x

TARGET_DIR="/media/ephemeral"

DOCKER_VERSION=$(/usr/bin/docker --version | grep -o '[0-9]*\.[0-9]*\.[0-9]')

if [ ! -e ${TARGET_DIR}/docker-${DOCKER_VERSION} ] ; then
    rm -f ${TARGET_DIR}/docker-${DOCKER_VERSION}_part
    curl -o ${TARGET_DIR}/docker-${DOCKER_VERSION}_part --retry 10 https://get.docker.com/builds/Linux/x86_64/docker-${DOCKER_VERSION}
    chmod +x ${TARGET_DIR}/docker-${DOCKER_VERSION}_part
    mv ${TARGET_DIR}/docker-${DOCKER_VERSION}_part ${TARGET_DIR}/docker-${DOCKER_VERSION}
    echo "Downloaded: ${TARGET_DIR}/docker-${DOCKER_VERSION}"
else
    echo "found ${TARGET_DIR}/docker-${DOCKER_VERSION}"
fi
