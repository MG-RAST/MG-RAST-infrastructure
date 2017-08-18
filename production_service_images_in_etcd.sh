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
#curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-v4-web-v4-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/66900208-cf72-459a-80d3-d067c40d0d26"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-v4-web-v4-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/b50afaff-bcd6-4e6d-bec5-a6c658592906"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-v4-web-v4-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/d67f6b22-06f3-4c30-b84a-412ba9bbc1ab"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-v4-web-v4-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/9d1bebf4-5c06-4c23-9645-92a83ec88ffb"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-v4-web-v4-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/bd154c48-d28d-4506-8a42-70f54146e1b9"
curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-v4-web-v4-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/73e65344-38e7-4f92-8041-537014763c77"
#v4-dev
curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-v4-web-v4-web-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/73e65344-38e7-4f92-8041-537014763c77"

#api-server-[channel]
#CHANNEL: api
#curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/c43b1253-f219-47d5-b8ff-5399ee13b8d6"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/c841fdfe-4717-4f57-a950-ba7f64f186c9"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/74e3d432-e3f5-491f-8440-a4999a3ba3a3"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/6f99a7a6-664b-495e-9cbc-801c493cf24c"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/dcc8bef2-a4ef-4a74-b81e-d31dff261d15"
curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/4fc3ce9b-64c7-452f-ac15-d666ebadc150"
#channel: api-dev
curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/dcc8bef2-a4ef-4a74-b81e-d31dff261d15"

#awe server
# v0.9.46
#curl -L http://127.0.0.1:2379/v2/keys/service_images/awe-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/0628aa3b-2c2f-48fc-88f5-15ec41794c70"
# v0.9.48
#curl -L http://127.0.0.1:2379/v2/keys/service_images/awe-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/56f05f1b-00a9-414d-816b-3857945941f4"
# v0.9.49
#curl -L http://127.0.0.1:2379/v2/keys/service_images/awe-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/50285c92-76b9-43fe-8668-9fb053d066e6"
# v0.9.50
curl -L http://127.0.0.1:2379/v2/keys/service_images/awe-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/e76e0c55-4a6e-4f5b-8f66-1dd5585b793a"

#awe client
curl -L http://127.0.0.1:2379/v2/keys/service_images/awe-client/shock -XPUT -d value="shock.metagenomics.anl.gov/node/e76e0c55-4a6e-4f5b-8f66-1dd5585b793a"

# latest pipeline
#shock.metagenomics.anl.gov/node/3f919e5c-cf21-40ca-9a3c-3f78bfa991db


####### not production #######

#mysql_replica_metadata
#curl -L http://127.0.0.1:2379/v2/keys/service_images/mysql_replica_metadata/shock -XPUT -d value="shock.metagenomics.anl.gov/node/959090d2-172b-4f12-a10c-4907cff3cd96"

#mysql_galera_metadata
#curl -L http://127.0.0.1:2379/v2/keys/service_images/mysql_galera_metadata/shock -XPUT -d value="shock.metagenomics.anl.gov/node/758776ff-c4dc-45ee-8e0b-9d9786467876"

#opscenter server
#curl -L http://127.0.0.1:2379/v2/keys/service_images/opscenter/shock -XPUT -d value="shock.metagenomics.anl.gov/node/a030ea5b-3971-43c6-8574-6f82c510fca2"
