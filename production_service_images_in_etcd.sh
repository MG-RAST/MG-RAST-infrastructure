#!/bin/sh
set -x
set -e

# service configuration

# mg-rast-nginx (note that nginx and confd use the same image)
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-nginx/shock -XPUT -d value="shock.metagenomics.anl.gov/node/0ccda654-ba7d-44c8-9d98-7ac519655a01"

# mg-rast-confd (note that nginx and confd use the same image)
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-confd/shock -XPUT -d value="shock.metagenomics.anl.gov/node/0ccda654-ba7d-44c8-9d98-7ac519655a01"


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
#curl -L http://127.0.0.1:4001/v2/keys/service_images/solr-metagenome/shock -XPUT -d value="shock.metagenomics.anl.gov/node/163fc5e8-9397-42b5-900d-60e34aa4eb8b"
curl -L http://127.0.0.1:4001/v2/keys/service_images/solr-metagenome/shock -XPUT -d value="shock.metagenomics.anl.gov/node/f671d166-9928-4179-bd82-1b459a84ae21"

# mg-rast-v4-web
#v4
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v4-web-v4-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/7b822568-7e44-4434-9d55-25f564b51448"
#v4-dev
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v4-web-v4-web-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/7b822568-7e44-4434-9d55-25f564b51448"

# mg-rast-v3-web-[channel]
#channel: v3-web
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v3-web-v3-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/9a3f9b23-5aee-4776-83fb-6c6998327a27"
#channel: v3-web-dev
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v3-web-v3-web-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/9a3f9b23-5aee-4776-83fb-6c6998327a27"

#api-server-[channel]
#channel: api
curl -L http://127.0.0.1:4001/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/5b26c996-740c-4e6f-abd2-4a4ea149a4c6"
#channel: api-dev
curl -L http://127.0.0.1:4001/v2/keys/service_images/api-server-api-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/5b26c996-740c-4e6f-abd2-4a4ea149a4c6"

#awe server
curl -L http://127.0.0.1:4001/v2/keys/service_images/awe-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/3a5e1f94-3921-4ae8-a208-53dda7aaeecb"
#awe client
curl -L http://127.0.0.1:4001/v2/keys/service_images/awe-client/shock -XPUT -d value="shock.metagenomics.anl.gov/node/62e626cd-c385-4018-9b46-f18e6ed6bed2"

#memcached server
curl -L http://127.0.0.1:4001/v2/keys/service_images/memcached/shock -XPUT -d value="shock.metagenomics.anl.gov/node/cc8df996-0682-461f-b1f3-616c23cb433e"

#cassandra node
curl -L http://127.0.0.1:4001/v2/keys/service_images/cassandra/shock -XPUT -d value="shock.metagenomics.anl.gov/node/f5d56f74-fd96-4ea2-87b9-2ecf62717a14"

#opscenter server
curl -L http://127.0.0.1:4001/v2/keys/service_images/opscenter/shock -XPUT -d value="shock.metagenomics.anl.gov/node/a030ea5b-3971-43c6-8574-6f82c510fca2"

# mongo replica
#curl -L http://127.0.0.1:4001/v2/keys/service_images/mongodb-replica/shock -XPUT -d value="shock.metagenomics.anl.gov/node/7426ffca-9554-4412-98a2-d392ada8a2c7"

