#!/bin/sh

set -x
set -e


# mg-rast-nginx (note that nginx and confd use the same image)
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-nginx/shock -XPUT -d value="shock.metagenomics.anl.gov/node/a34d112c-5f29-479d-af72-783b3410f264"

# mg-rast-confd (note that nginx and confd use the same image)
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-confd/shock -XPUT -d value="shock.metagenomics.anl.gov/node/a34d112c-5f29-479d-af72-783b3410f264"


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

