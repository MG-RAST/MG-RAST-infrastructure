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
#curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-v4-web-v4-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/fa255f80-8d1b-4be3-8743-758cc960aae7"
#curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v4-web-v4-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/74845e0c-0d05-4dfd-bb96-5a5b6cb89506"
#curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v4-web-v4-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/bc4108d8-c494-4241-8eb5-d0b0a6f68433"
#curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v4-web-v4-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/7fbdbbdc-c846-4366-9890-67f013412d87"
#curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v4-web-v4-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/b369a4e5-6615-44c7-836e-9f399eefaf58"
#curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v4-web-v4-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/9683243d-f3ff-49f8-b411-6f6fa41c0904"
curl -L http://127.0.0.1:4001/v2/keys/service_images/mg-rast-v4-web-v4-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/592a7cba-c5a6-4aab-a747-382cfabe9116"


#v4-dev
#curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-v4-web-v4-web-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/9683243d-f3ff-49f8-b411-6f6fa41c0904"
curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-v4-web-v4-web-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/592a7cba-c5a6-4aab-a747-382cfabe9116"

#api-server-[channel]
#CHANNEL: api
#curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/861d9c62-9ffb-417f-a027-85769f09b364"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/580f9ca2-8c54-4d39-a4e4-2b53b0b49da2"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/e49fcf75-815b-4bd9-9dc7-70c5fabf6416"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/3ea55b1e-bc19-49c1-9f05-6061c9543027"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/bc54813c-0584-4e0e-b754-4f404eb896cb"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/b42f51c9-30e4-4efe-9599-164e879711cc"
curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/d87d0dd7-3f38-4cc5-ac89-4a57c4637761"
#channel: api-dev
curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/d87d0dd7-3f38-4cc5-ac89-4a57c4637761"

#awe server
# v0.9.65
#curl -L http://127.0.0.1:2379/v2/keys/service_images/awe-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/2215041c-3ad2-41ae-9e08-04106ca872b0"
# v0.9.66
#curl -L http://127.0.0.1:2379/v2/keys/service_images/awe-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/58ab3827-165e-4026-93f5-6606dd4e0a28"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/awe-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/a7686032-3ee8-4f89-ab9f-fc94df99d4f6"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/awe-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/36a363ec-01b1-4d73-acfe-b50190908410"
# v0.9.67
#curl -L http://127.0.0.1:2379/v2/keys/service_images/awe-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/cdd4f3ae-89c9-4909-a1d9-b754c49bb230"
# v0.9.68
#curl -L http://127.0.0.1:2379/v2/keys/service_images/awe-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/90c78286-f76d-43b2-9f8d-c64891ddc7ce"
# v0.9.68+
curl -L http://127.0.0.1:2379/v2/keys/service_images/awe-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/def4dbd9-c526-4092-82d9-07e64ef953d0"

#awe client
curl -L http://127.0.0.1:2379/v2/keys/service_images/awe-client/shock -XPUT -d value="shock.metagenomics.anl.gov/node/d3c5f1ec-8072-405d-aaae-950dec557f76"

# previous pipeline
#shock.metagenomics.anl.gov/node?query&type=dockerimage&repository=mgrast/pipeline
#shock.metagenomics.anl.gov/node/6683b0c4-cbb2-4286-9ffd-633426c79776
#shock.metagenomics.anl.gov/node/91b01695-9f4a-4a6a-b20f-0bf5649e9ec4
# latest pipeline
#shock.metagenomics.anl.gov/node/7664d8f0-dd95-4aa7-826b-d0a70dc354d5

####### not production #######

#mysql_replica_metadata
#curl -L http://127.0.0.1:2379/v2/keys/service_images/mysql_replica_metadata/shock -XPUT -d value="shock.metagenomics.anl.gov/node/959090d2-172b-4f12-a10c-4907cff3cd96"

#mysql_galera_metadata
#curl -L http://127.0.0.1:2379/v2/keys/service_images/mysql_galera_metadata/shock -XPUT -d value="shock.metagenomics.anl.gov/node/758776ff-c4dc-45ee-8e0b-9d9786467876"

#opscenter server
#curl -L http://127.0.0.1:2379/v2/keys/service_images/opscenter/shock -XPUT -d value="shock.metagenomics.anl.gov/node/a030ea5b-3971-43c6-8574-6f82c510fca2"
