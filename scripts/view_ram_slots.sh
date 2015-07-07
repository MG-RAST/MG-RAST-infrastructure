#!/bin/bash
set -e
set -x
docker run --rm --privileged -t -v /dev/mem:/dev/mem ubuntu:14.04 bash -c 'apt-get install dmidecode  ; dmidecode -t 17 | grep -i "size"'