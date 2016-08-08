#!/bin/sh
set -x
set -e

# production service configuration

# mg-rast-nginx (note that nginx and confd use the same image)
curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-nginx/shock -XPUT -d value="shock.metagenomics.anl.gov/node/d6ec281e-9691-4fbe-bc72-a37513675a27"

# mg-rast-confd (note that nginx and confd use the same image)
curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-confd/shock -XPUT -d value="shock.metagenomics.anl.gov/node/d6ec281e-9691-4fbe-bc72-a37513675a27"

# log-courier
#curl -L http://127.0.0.1:2379/v2/keys/service_images/log-courier/shock -XPUT -d value="shock.metagenomics.anl.gov/node/97a227b6-7e0e-49c9-8ca4-4e11b43d7d05"

# solr-m5nr
curl -L http://127.0.0.1:2379/v2/keys/service_images/solr-m5nr/shock -XPUT -d value="shock.metagenomics.anl.gov/node/6c6c1d0d-3195-46d0-9fdb-00fb9b6b60b9"

# solr-metagenome
curl -L http://127.0.0.1:2379/v2/keys/service_images/solr-metagenome/shock -XPUT -d value="shock.metagenomics.anl.gov/node/6472aaec-12e1-44a0-8152-da98da0ce136"

# mg-rast-v4-web
#v4
curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-v4-web-v4-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/5789743c-5721-4a3c-a7cc-a217a2d91454"
#v4-dev
curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-v4-web-v4-web-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/171fd649-9486-4089-82df-7a60023e8943"

# mg-rast-v3-web-[channel]
#channel: v3-web
curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-v3-web-v3-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/06815b5e-22de-4942-9478-398ca764db95"
#channel: v3-web-dev
curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-v3-web-v3-web-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/06815b5e-22de-4942-9478-398ca764db95"

#api-server-[channel]
#channel: api
#curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/64ff1d47-facf-4ee7-9321-9dc6b537b6c4"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/81548d51-e570-44e2-8da6-90cb53c79972"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/fa226330-f714-4b71-8db3-22ec24fff1af"
curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/b430c25c-0dfb-4b9d-ba75-1902e9e0802e"
#channel: api-dev
curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/b430c25c-0dfb-4b9d-ba75-1902e9e0802e"

#awe server
curl -L http://127.0.0.1:2379/v2/keys/service_images/awe-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/d1058716-af9b-4aba-9821-b631988e575c"
# this was the new container, but did nowork: curl -L http://127.0.0.1:2379/v2/keys/service_images/awe-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/5aaa1244-bb27-4b4a-b84a-ce65e1cc3242"

#awe client
curl -L http://127.0.0.1:2379/v2/keys/service_images/awe-client/shock -XPUT -d value="shock.metagenomics.anl.gov/node/5aaa1244-bb27-4b4a-b84a-ce65e1cc3242"

#analysis pipeline
#shock.metagenomics.anl.gov/node/734c5091-6059-4361-88b3-72fddc7d445c

####### not production #######

#memcached server
#curl -L http://127.0.0.1:2379/v2/keys/service_images/memcached/shock -XPUT -d value="shock.metagenomics.anl.gov/node/cc8df996-0682-461f-b1f3-616c23cb433e"

#cassandra node
#curl -L http://127.0.0.1:2379/v2/keys/service_images/cassandra/shock -XPUT -d value="shock.metagenomics.anl.gov/node/5aad2de7-97c0-49bb-9b63-d3a86b15b5d7"

# mysql_metadata
#curl -L http://127.0.0.1:2379/v2/keys/service_images/mysql_metadata/shock -XPUT -d value="shock.metagenomics.anl.gov/node/25fd3da0-769c-4a10-af0b-13d6659aee56"

# mysql_replica_metadata
#curl -L http://127.0.0.1:2379/v2/keys/service_images/mysql_replica_metadata/shock -XPUT -d value="shock.metagenomics.anl.gov/node/959090d2-172b-4f12-a10c-4907cff3cd96"

# mysql_galera_metadata
#curl -L http://127.0.0.1:2379/v2/keys/service_images/mysql_galera_metadata/shock -XPUT -d value="shock.metagenomics.anl.gov/node/758776ff-c4dc-45ee-8e0b-9d9786467876"

# mongo replica
#curl -L http://127.0.0.1:2379/v2/keys/service_images/mongodb-replica/shock -XPUT -d value="shock.metagenomics.anl.gov/node/7426ffca-9554-4412-98a2-d392ada8a2c7"

#pgpool
#curl -L http://127.0.0.1:2379/v2/keys/service_images/pgpool/shock -XPUT -d value="shock.metagenomics.anl.gov/node/c9e3a19e-3c17-47c3-aac1-9fb6580b6844"

#opscenter server
#curl -L http://127.0.0.1:2379/v2/keys/service_images/opscenter/shock -XPUT -d value="shock.metagenomics.anl.gov/node/a030ea5b-3971-43c6-8574-6f82c510fca2"
