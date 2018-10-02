#!/bin/bash
set -e
set -x

git clone https://github.com/MG-RAST/MG-RAST-infrastructure.git
cd MG-RAST-infrastructure/services/nginx/docker
docker rm -f mgrast_nginx mgrast_confd ; docker rmi mgrast/nginxconfd
TAG=`date +"%Y%m%d.%H%M"`
docker build  --no-cache -t mgrast/nginxconfd:${TAG} .

skycore push mgrast/nginxconfd:${TAG}

