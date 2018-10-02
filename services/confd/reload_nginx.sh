#!/bin/bash
set -e
set -x

# first check if container exists and is running, then reload nginx config.
if [ "$(docker inspect --format="{{ .State.Running }}" mgrast_nginx 2> /dev/null)_" == "true_" ] ; then
  /usr/bin/docker exec mgrast_nginx /usr/sbin/nginx -s reload -c /config/nginx.conf
fi
