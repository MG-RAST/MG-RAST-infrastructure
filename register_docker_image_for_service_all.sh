#!/bin/sh
set -x
set -e

# service configuration

# mg-rast-nginx (note that nginx and confd use the same image)
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-nginx/shock -XPUT -d value="shock.metagenomics.anl.gov/node/c474bcd6-dd31-496f-af95-ba000cd3f2ed"

# mg-rast-confd (note that nginx and confd use the same image)
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-confd/shock -XPUT -d value="shock.metagenomics.anl.gov/node/c474bcd6-dd31-496f-af95-ba000cd3f2ed"


# log-courier
curl -L http://127.0.0.1:4001/v2/keys/service_images/log-courier/shock -XPUT -d value="shock.metagenomics.anl.gov/node/97a227b6-7e0e-49c9-8ca4-4e11b43d7d05"

# mysql_metadata
curl -L http://127.0.0.1:4001/v2/keys/service_images/mysql_metadata/shock -XPUT -d value="shock.metagenomics.anl.gov/node/25fd3da0-769c-4a10-af0b-13d6659aee56"

# mysql_replica_metadata
curl -L http://127.0.0.1:4001/v2/keys/service_images/mysql_replica_metadata/shock -XPUT -d value="shock.metagenomics.anl.gov/node/959090d2-172b-4f12-a10c-4907cff3cd96"

# mysql_galera_metadata
curl -L http://127.0.0.1:4001/v2/keys/service_images/mysql_galera_metadata/shock -XPUT -d value="shock.metagenomics.anl.gov/node/758776ff-c4dc-45ee-8e0b-9d9786467876"

# solr-m5nr
curl -L http://127.0.0.1:4001/v2/keys/service_images/solr-m5nr/shock -XPUT -d value="shock.metagenomics.anl.gov/node/37b92d33-1467-4656-8e17-c95b51437c43"

# solr-metagenome
curl -L http://127.0.0.1:4001/v2/keys/service_images/solr-metagenome/shock -XPUT -d value="shock.metagenomics.anl.gov/node/163fc5e8-9397-42b5-900d-60e34aa4eb8b"

# mg-rast-v4-web
#v4
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v4-web-v4-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/f7cf57b9-686c-4858-93ee-0b3fa51a40b5"
#v4-dev
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v4-web-v4-web-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/f7cf57b9-686c-4858-93ee-0b3fa51a40b5"

# mg-rast-v3-web-[channel]
#channel: v3-web
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v3-web-v3-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/07ab9aa2-d8e4-461e-8254-337bc6653acc"
#channel: v3-web-dev
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v3-web-v3-web-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/07ab9aa2-d8e4-461e-8254-337bc6653acc"

#api-server-[channel]
#channel: api
curl -L http://127.0.0.1:4001/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/456a4e77-22b1-4e4b-a945-5026a555c698"
#channel: api-dev
curl -L http://127.0.0.1:4001/v2/keys/service_images/api-server-api-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/456a4e77-22b1-4e4b-a945-5026a555c698"

#awe server
curl -L http://127.0.0.1:4001/v2/keys/service_images/awe-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/7257ba02-8ee2-4e43-b933-cf743df82e17"

#memcached server
curl -L http://127.0.0.1:4001/v2/keys/service_images/memcached/shock -XPUT -d value="shock.metagenomics.anl.gov/node/cc8df996-0682-461f-b1f3-616c23cb433e"

#cassandra node
curl -L http://127.0.0.1:4001/v2/keys/service_images/cassandra/shock -XPUT -d value="shock.metagenomics.anl.gov/node/f5dfa9a3-d1f8-4aff-b123-40e763f2723a"

#opscenter server
curl -L http://127.0.0.1:4001/v2/keys/service_images/opscenter/shock -XPUT -d value="shock.metagenomics.anl.gov/node/a030ea5b-3971-43c6-8574-6f82c510fca2"

# mongo replica
curl -L http://127.0.0.1:4001/v2/keys/service_images/mongodb-replica/shock -XPUT -d value="shock.metagenomics.anl.gov/node/7426ffca-9554-4412-98a2-d392ada8a2c7"

# production services:

# fleetctl start mg-rast-confd.service # global unit that runs on multiple machines
# fleetctl start mg-rast-nginx@1.service
# fleetctl start solr-m5nr@1.service
# fleetctl start solr-metagenome@1.service
# fleetctl start mongodb-replica{,-discovery}@1.shock.service
#### manualy set / load primary node before starting update service
# docker exec ${CONTAINER} mongo --quiet -u $USER -p $PASS --eval 'printjson(rs.initiate({_id:"$CHANNEL",members:[{_id:0,host:"${COREOS_PUBLIC_IPV4}:27017"}]}))' admin
# fleetctl start mongodb-replica-update@1.shock.service
# fleetctl start mongodb-replica{,-discovery,-update}@{2,3}.shock.service
# fleetctl start mongodb-replica{,-discovery}@1.awe.service
#### manualy set / load primary node before starting update service
# docker exec ${CONTAINER} mongo --quiet -u $USER -p $PASS --eval 'printjson(rs.initiate({_id:"$CHANNEL",members:[{_id:0,host:"${COREOS_PUBLIC_IPV4}:27017"}]}))' admin
# fleetctl start mongodb-replica-update@1.awe.service
# fleetctl start mongodb-replica{,-discovery,-update}@{2,3}.awe.service
# fleetctl start awe-server{,-discovery}@1.service
# fleetctl start mysql_metadata@1.service
# fleetctl start memcached.service # global unit that runs on multiple machines
# fleetctl start memcached-discovery.service # global unit that runs on multiple machines
# fleetctl start cassandra-seed{,-discovery}@{1,2}.service
# fleetctl start cassandra-node@{1,2,3,4,5,6}.service
# fleetctl start api-server{,-discovery,-update}@{1,2,3}.api.service
# fleetctl start mg-rast-v3-web{,-discovery}@{1,2,3,4}.v3-web.service

# develop services:

# fleetctl start mg-rast-v4-web{,-discovery}@1.v4-web.service
# fleetctl start mg-rast-v4-web{,-discovery}@1.v4-web-dev.service
# fleetctl start mg-rast-v3-web{,-discovery}@1.v3-web-dev.service
# fleetctl start cadvisor.service
# fleetctl start opscenter@1.service
# fleetctl start fleetui@.1.service
