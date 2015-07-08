#!/bin/sh
set -x
set -e


# service configuration


# mg-rast-nginx (note that nginx and confd use the same image)
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-nginx/shock -XPUT -d value="shock.metagenomics.anl.gov/node/a83e38ca-8037-4cbc-8b4a-11c25fa80765"

# mg-rast-confd (note that nginx and confd use the same image)
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-confd/shock -XPUT -d value="shock.metagenomics.anl.gov/node/a83e38ca-8037-4cbc-8b4a-11c25fa80765"


# mysql_metadata
curl -L http://127.0.0.1:4001/v2/keys/service_images/mysql_metadata/shock -XPUT -d value="shock.metagenomics.anl.gov/node/25fd3da0-769c-4a10-af0b-13d6659aee56"


# solr-m5nr
curl -L http://127.0.0.1:4001/v2/keys/service_images/solr-m5nr/shock -XPUT -d value="shock.metagenomics.anl.gov/node/37b92d33-1467-4656-8e17-c95b51437c43"

# solr-metagenome
curl -L http://127.0.0.1:4001/v2/keys/service_images/solr-metagenome/shock -XPUT -d value="shock.metagenomics.anl.gov/node/6d69bd20-1403-4bde-b52f-208db29f5c20"

# mg-rast-v4-web
#v4
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v4-web-v4/shock -XPUT -d value="shock.metagenomics.anl.gov/node/247d49e8-5699-4329-92cc-774a210b8dff"
#v4-dev
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v4-web-v4-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/247d49e8-5699-4329-92cc-774a210b8dff"
#v4-test
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v4-web-v4-test/shock -XPUT -d value="shock.metagenomics.anl.gov/node/ab071920-a117-441e-9084-4d4ef5c7ca5c"

# mg-rast-v3-web-[channel]
#channel: v3-web
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v3-web-v3-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/3ee63711-9098-4ae5-95b9-e777da6db61b"
#channel: v3-web-dev
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v3-web-v3-web-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/3ee63711-9098-4ae5-95b9-e777da6db61b"
#channel: v3-web-test
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v3-web-v3-web-test/shock -XPUT -d value="shock.metagenomics.anl.gov/node/3ee63711-9098-4ae5-95b9-e777da6db61b"




#api server
curl -L http://127.0.0.1:4001/v2/keys/service_images/api-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/fc032536-3022-428f-9ac2-948674c13b9b"

#awe server
curl -L http://127.0.0.1:4001/v2/keys/service_images/awe-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/af0d8ec4-bc6e-43d2-9a9b-de6c725d38a3"

#memcached server
curl -L http://127.0.0.1:4001/v2/keys/service_images/memcached/shock -XPUT -d value="shock.metagenomics.anl.gov/node/cc8df996-0682-461f-b1f3-616c23cb433e"

#cassandra node
curl -L http://127.0.0.1:4001/v2/keys/service_images/cassandra-node/shock -XPUT -d value="shock.metagenomics.anl.gov/node/2dd70ba4-2b75-4c5c-ad30-79ec9f261387"

#opscenter server
curl -L http://127.0.0.1:4001/v2/keys/service_images/opscenter/shock -XPUT -d value="shock.metagenomics.anl.gov/node/388ba3fe-3cd2-4965-8c25-6c85faeec862"

# production services:

# fleetctl start mg-rast-confd.service # global unit that runs on multiple machines
# fleetctl start mg-rast-nginx@1.service
# fleetctl start solr-m5nr@1.service
# fleetctl start solr-metagenome@1.service
# fleetctl start api-server@1.service
# fleetctl start awe-server{,-mongodb,-discovery}@1.service
# fleetctl start memcached.service # global unit that runs on multiple machines
# fleetctl start cassandra-node.service # global unit that runs on multiple machines
# fleetctl start opscenter@1.service

# develop services:
# fleetctl start mysql_metadata@1.service
# fleetctl start mg-rast-v4-web{,-discovery}@{1..2}.v4-web.service
# fleetctl start mg-rast-v4-web{,-discovery}@{1..2}.v4-web-dev.service
# fleetctl start mg-rast-v3-web{,-discovery}@{1..2}.v3-web.service
# fleetctl start mg-rast-v3-web{,-discovery}@{1..2}.v3-web-dev.service
# fleetctl start cadvisor.service

