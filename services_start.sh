#!/bin/sh

# WARNING: Please run register_docker_image_for_service_all.sh first!



set -x
set -e

cd fleet-units

# nginx
fleetctl start mg-rast-nginx@1.service
fleetctl start mg-rast-confd@1.service


#production web
#fleetctl start mg-rast-v4-web{,-discovery}@{1..3}.v4.service



fleetctl start solr-m5nr@1.service

fleetctl start solr-metagenome@1.service