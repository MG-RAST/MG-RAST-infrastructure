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
curl -L http://127.0.0.1:4001/v2/keys/service_images/solr-metagenome/shock -XPUT -d value="shock.metagenomics.anl.gov/node/7b05ffc1-9c3d-41ac-8b4c-8b3a1e482673"

# mg-rast-v4-web
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v4-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/247d49e8-5699-4329-92cc-774a210b8dff"

