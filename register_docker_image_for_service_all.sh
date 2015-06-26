#!/bin/sh
set -x
set -e


# service configuration

# mg-rast-nginx (note that nginx and confd use the same image)
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-nginx/shock -XPUT -d value="shock.metagenomics.anl.gov/node/f0aba6ce-1d10-495b-82a2-5921107848c1"

# mg-rast-confd (note that nginx and confd use the same image)
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-confd/shock -XPUT -d value="shock.metagenomics.anl.gov/node/f0aba6ce-1d10-495b-82a2-5921107848c1"


# solr-m5nr
curl -L http://127.0.0.1:4001/v2/keys/service_images/solr-m5nr/shock -XPUT -d value="shock.metagenomics.anl.gov/node/37b92d33-1467-4656-8e17-c95b51437c43"

# solr-metagenome
curl -L http://127.0.0.1:4001/v2/keys/service_images/solr-metagenome/shock -XPUT -d value="shock.metagenomics.anl.gov/node/6d69bd20-1403-4bde-b52f-208db29f5c20"

# mg-rast-v4-web
#curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v4-web-v4/shock -XPUT -d value="shock.metagenomics.anl.gov/node/247d49e8-5699-4329-92cc-774a210b8dff"

curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v4-web-v4/shock -XPUT -d value="shock.metagenomics.anl.gov/node/247d49e8-5699-4329-92cc-774a210b8dff"
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v4-web-v4-beta/shock -XPUT -d value="shock.metagenomics.anl.gov/node/247d49e8-5699-4329-92cc-774a210b8dff"
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v4-web-v4-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/247d49e8-5699-4329-92cc-774a210b8dff"
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v4-web-test/shock -XPUT -d value="shock.metagenomics.anl.gov/node/ab071920-a117-441e-9084-4d4ef5c7ca5c"

#api server
curl -L http://127.0.0.1:4001/v2/keys/service_images/api-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/fc032536-3022-428f-9ac2-948674c13b9b"

#awe server
curl -L http://127.0.0.1:4001/v2/keys/service_images/awe-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/af0d8ec4-bc6e-43d2-9a9b-de6c725d38a3"



# production services:

# fleetctl start mg-rast-nginx-image.service
# fleetctl start mg-rast-{confd,nginx}@1.service
# fleetctl start solr-m5nr@1.service
# fleetctl start solr-metagenome@1.service
# fleetctl start api-server@1.service

# develop services:
# fleetctl start mg-rast-v4-v4-web{,-discovery}@{1..2}.v4.service
# fleetctl start mg-rast-v4-v3-web{,-discovery}@{1..2}.v4.service
# fleetctl start cadvisor.service

