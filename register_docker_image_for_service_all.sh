#!/bin/sh
set -x
set -e

# service configuration

# mg-rast-nginx (note that nginx and confd use the same image)
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-nginx/shock -XPUT -d value="shock.metagenomics.anl.gov/node/2505c17e-848f-41c0-b722-4bb782a0275c"

# mg-rast-confd (note that nginx and confd use the same image)
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-confd/shock -XPUT -d value="shock.metagenomics.anl.gov/node/2505c17e-848f-41c0-b722-4bb782a0275c"

# mysql_metadata
curl -L http://127.0.0.1:4001/v2/keys/service_images/mysql_metadata/shock -XPUT -d value="shock.metagenomics.anl.gov/node/25fd3da0-769c-4a10-af0b-13d6659aee56"

# mysql_replica_metadata
curl -L http://127.0.0.1:4001/v2/keys/service_images/mysql_replica_metadata/shock -XPUT -d value="shock.metagenomics.anl.gov/node/959090d2-172b-4f12-a10c-4907cff3cd96"

# mysql_galera_metadata
curl -L http://127.0.0.1:4001/v2/keys/service_images/mysql_galera_metadata/shock -XPUT -d value="shock.metagenomics.anl.gov/node/758776ff-c4dc-45ee-8e0b-9d9786467876"

# solr-m5nr
curl -L http://127.0.0.1:4001/v2/keys/service_images/solr-m5nr/shock -XPUT -d value="shock.metagenomics.anl.gov/node/37b92d33-1467-4656-8e17-c95b51437c43"

# solr-metagenome
curl -L http://127.0.0.1:4001/v2/keys/service_images/solr-metagenome/shock -XPUT -d value="shock.metagenomics.anl.gov/node/6d69bd20-1403-4bde-b52f-208db29f5c20"

# mg-rast-v4-web
#v4
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v4-web-v4-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/9fa3a80b-766a-4093-9a18-cda4abf0a605"
#v4-dev
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v4-web-v4-web-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/9fa3a80b-766a-4093-9a18-cda4abf0a605"

# mg-rast-v3-web-[channel]
#channel: v3-web
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v3-web-v3-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/81e17442-9110-4a60-945e-6c6e9046f456"
#channel: v3-web-dev
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v3-web-v3-web-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/81e17442-9110-4a60-945e-6c6e9046f456"

#api-server-[channel]
#channel: api
curl -L http://127.0.0.1:4001/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/0732a631-60df-41bd-862f-c1c562c610fb"
#channel: api-dev
curl -L http://127.0.0.1:4001/v2/keys/service_images/api-server-api-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/0732a631-60df-41bd-862f-c1c562c610fb"

#awe server
curl -L http://127.0.0.1:4001/v2/keys/service_images/awe-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/7257ba02-8ee2-4e43-b933-cf743df82e17"

#memcached server
curl -L http://127.0.0.1:4001/v2/keys/service_images/memcached/shock -XPUT -d value="shock.metagenomics.anl.gov/node/cc8df996-0682-461f-b1f3-616c23cb433e"

#cassandra node
curl -L http://127.0.0.1:4001/v2/keys/service_images/cassandra/shock -XPUT -d value="shock.metagenomics.anl.gov/node/078b3746-c20a-44ff-8245-45e9de2dce12"

#opscenter server
curl -L http://127.0.0.1:4001/v2/keys/service_images/opscenter/shock -XPUT -d value="shock.metagenomics.anl.gov/node/a030ea5b-3971-43c6-8574-6f82c510fca2"

# mongo replica
curl -L http://127.0.0.1:4001/v2/keys/service_images/mongodb-replica/shock -XPUT -d value="shock.metagenomics.anl.gov/node/7426ffca-9554-4412-98a2-d392ada8a2c7"

# production services:

# fleetctl start api-server{,-discovery}@1.api.service
# fleetctl start mg-rast-confd.service # global unit that runs on multiple machines
# fleetctl start mg-rast-nginx@1.service
# fleetctl start solr-m5nr@1.service
# fleetctl start solr-metagenome@1.service
# fleetctl start mongodb-replica{,-discovery}@{1,2,3}.shock.service # manualy set primary node before starting update service
# fleetctl start mongodb-replica-update@{1,2,3}.shock.service
# fleetctl start mongodb-replica{,-discovery}@{1,2,3}.awe.service # manualy set primary node before starting update service
# fleetctl start mongodb-replica-update@{1,2,3}.awe.service
# fleetctl start awe-server{,-discovery}@1.service
# fleetctl start memcached.service # global unit that runs on multiple machines
# fleetctl start mg-rast-v3-web{,-discovery}@{1,2}.v3-web.service

# develop services:

# 
# fleetctl start mysql_metadata@1.service
# fleetctl start mg-rast-v4-web{,-discovery}@{1,2}.v4-web.service
# fleetctl start mg-rast-v4-web{,-discovery}@{1,2}.v4-web-dev.service
# fleetctl start mg-rast-v3-web{,-discovery}@{1,2}.v3-web-dev.service
# fleetctl start cadvisor.service
# fleetctl start opscenter@1.service
