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

# solr-m5nr
curl -L http://127.0.0.1:4001/v2/keys/service_images/solr-m5nr/shock -XPUT -d value="shock.metagenomics.anl.gov/node/37b92d33-1467-4656-8e17-c95b51437c43"

# solr-metagenome
curl -L http://127.0.0.1:4001/v2/keys/service_images/solr-metagenome/shock -XPUT -d value="shock.metagenomics.anl.gov/node/6d69bd20-1403-4bde-b52f-208db29f5c20"

# mg-rast-v4-web
#v4
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v4-web-v4-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/cc266f16-2854-424e-b0f5-dfdbe0e7f811"
#v4-dev
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v4-web-v4-web-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/cc266f16-2854-424e-b0f5-dfdbe0e7f811"
#v4-test
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v4-web-v4-web-test/shock -XPUT -d value="shock.metagenomics.anl.gov/node/cc266f16-2854-424e-b0f5-dfdbe0e7f811"

# mg-rast-v3-web-[channel]
#channel: v3-web
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v3-web-v3-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/c315a265-2a55-4f2a-9fb8-bdae88115401"
#channel: v3-web-dev
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v3-web-v3-web-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/c315a265-2a55-4f2a-9fb8-bdae88115401"
#channel: v3-web-test
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v3-web-v3-web-test/shock -XPUT -d value="shock.metagenomics.anl.gov/node/c315a265-2a55-4f2a-9fb8-bdae88115401"


#api-server-[channel]
#channel: api
curl -L http://127.0.0.1:4001/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/3de221ce-8946-470f-8a1c-987e8e70d797"
#channel: api-dev
curl -L http://127.0.0.1:4001/v2/keys/service_images/api-server-api-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/3de221ce-8946-470f-8a1c-987e8e70d797"
#channel: api-test
curl -L http://127.0.0.1:4001/v2/keys/service_images/api-server-api-test/shock -XPUT -d value="shock.metagenomics.anl.gov/node/3de221ce-8946-470f-8a1c-987e8e70d797"


#awe server
curl -L http://127.0.0.1:4001/v2/keys/service_images/awe-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/a156bd90-3a56-4fac-ae3c-3664deadecd2"

#memcached server
curl -L http://127.0.0.1:4001/v2/keys/service_images/memcached/shock -XPUT -d value="shock.metagenomics.anl.gov/node/cc8df996-0682-461f-b1f3-616c23cb433e"

#cassandra node
curl -L http://127.0.0.1:4001/v2/keys/service_images/cassandra-node/shock -XPUT -d value="shock.metagenomics.anl.gov/node/2dd70ba4-2b75-4c5c-ad30-79ec9f261387"

#opscenter server
curl -L http://127.0.0.1:4001/v2/keys/service_images/opscenter/shock -XPUT -d value="shock.metagenomics.anl.gov/node/388ba3fe-3cd2-4965-8c25-6c85faeec862"

# mongo replica
curl -L http://127.0.0.1:4001/v2/keys/service_images/mongodb-replica/shock -XPUT -d value="shock.metagenomics.anl.gov/node/7426ffca-9554-4412-98a2-d392ada8a2c7"

# production services:

# fleetctl start mg-rast-confd.service # global unit that runs on multiple machines
# fleetctl start mg-rast-nginx@1.service
# fleetctl start solr-m5nr@1.service
# fleetctl start solr-metagenome@1.service
# fleetctl start api-server@{1,2}.api.service # or api-dev !
# fleetctl start awe-server{,-discovery}@1.service
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

