#!/bin/bash
set -e
set -x

/usr/bin/docker exec mgrast_nginx /usr/sbin/nginx -s reload -c /Skycore/services/nginx/nginx.conf
