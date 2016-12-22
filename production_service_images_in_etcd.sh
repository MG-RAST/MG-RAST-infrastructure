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
curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-v4-web-v4-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/bfb919dc-b96d-4a6b-adca-ea6423bca8ae"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-v4-web-v4-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/d8c098f4-f1cf-4804-ac23-e9ce8f7d440f"

#v4-dev
curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-v4-web-v4-web-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/dc5e8c04-be69-46df-a958-f5c9d4b22d68"

# mg-rast-v3-web-[channel]
#channel: v3-web
#curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-v3-web-v3-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/53b3d791-6e18-48de-bd98-77fc8288c21a"
curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-v3-web-v3-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/6d274c3b-e936-4616-a566-ab183296dba8"
#channel: v3-web-dev
curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-v3-web-v3-web-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/6d274c3b-e936-4616-a566-ab183296dba8"

#api-server-[channel]
#channel: api
#curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/3369c672-6244-47b2-8f4e-7af408c06fc2"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/c0c49b6a-766e-4ea5-a818-5b0fddf54452"
curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/ef1b0a16-2f1d-4591-b381-599e24842c84"
#channel: api-dev
#curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/16d9552d-09a0-4785-bb6e-691e83216901"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/c0c49b6a-766e-4ea5-a818-5b0fddf54452"
curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/69069bb9-5050-42a8-bcbb-64ad012bfc21"
#channel: api-pql
curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api-pql/shock -XPUT -d value="shock.metagenomics.anl.gov/node/743292ff-3c85-4d14-a9ad-dd40632c5b75"

#awe server
#http://shock.metagenomics.anl.gov/node/68fee2c3-fc73-4b4e-9a47-2e8d6d512b95
#curl -L http://127.0.0.1:2379/v2/keys/service_images/awe-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/ec22ed3b-2b27-45e7-b5e8-d3896dd32a9d"
curl -L http://127.0.0.1:2379/v2/keys/service_images/awe-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/f2b11496-5f0e-4d7e-81c1-55322254d9a8"

#awe client
#http://shock.metagenomics.anl.gov/node/68fee2c3-fc73-4b4e-9a47-2e8d6d512b95
#curl -L http://127.0.0.1:2379/v2/keys/service_images/awe-client/shock -XPUT -d value="shock.metagenomics.anl.gov/node/ec22ed3b-2b27-45e7-b5e8-d3896dd32a9d"
curl -L http://127.0.0.1:2379/v2/keys/service_images/awe-client/shock -XPUT -d value="shock.metagenomics.anl.gov/node/f2b11496-5f0e-4d7e-81c1-55322254d9a8"

# latest pipeline
#shock.metagenomics.anl.gov/node/2d0f16cb-b501-4516-83b4-89b6aa67dcf5

# test pipeline
#shock.metagenomics.anl.gov/node/7e563784-6286-48e2-9773-496e0899b569

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
