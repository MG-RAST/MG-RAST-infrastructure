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
#curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-v4-web-v4-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/25a24e2d-0c61-4fff-a761-77ab3e22c71a"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-v4-web-v4-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/2356dd40-b624-4373-9420-0403efd72398"
curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-v4-web-v4-web/shock -XPUT -d value="shock.metagenomics.anl.gov/node/35c336aa-9769-4900-81c7-00eaf8d1f7d2"
#v4-dev
curl -L http://127.0.0.1:2379/v2/keys/service_images/mg-rast-v4-web-v4-web-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/35c336aa-9769-4900-81c7-00eaf8d1f7d2"

#api-server-[channel]
#CHANNEL: api
curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/5e77cb0d-a150-48c6-aa3d-890c40354704"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/2b1884ad-7402-4fa0-9eb6-a7b409e7af64"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/9b50a8c1-6b81-4db1-846e-65a856c88c23"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/f603a3e8-fb89-4ad6-82db-eb560ab2d1d6"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/5053fe41-ff5a-4771-ab79-7d44018e4bde"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/ed4309b6-675f-4651-947f-2c136a61ed0b"
#curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api/shock -XPUT -d value="shock.metagenomics.anl.gov/node/7323a26c-6a58-49b5-a92c-534a7db83b5a"

#channel: api-dev
curl -L http://127.0.0.1:2379/v2/keys/service_images/api-server-api-dev/shock -XPUT -d value="shock.metagenomics.anl.gov/node/5e77cb0d-a150-48c6-aa3d-890c40354704"

#awe server
#http://shock.metagenomics.anl.gov/node/68fee2c3-fc73-4b4e-9a47-2e8d6d512b95
#this is develop branch NOT debug mode:
#  curl -L http://127.0.0.1:2379/v2/keys/service_images/awe-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/ec22ed3b-2b27-45e7-b5e8-d3896dd32a9d"
#this is develop branch WITH debug mode AND recover limit
#curl -L http://127.0.0.1:2379/v2/keys/service_images/awe-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/b3b51fdc-ccbd-41c4-a121-e459b67a128b"
#this is develop branch NOT debug mode AND recover limit:
curl -L http://127.0.0.1:2379/v2/keys/service_images/awe-server/shock -XPUT -d value="shock.metagenomics.anl.gov/node/3696175a-07ff-4bcf-a222-0ae226e04aaa"

#awe client
#http://shock.metagenomics.anl.gov/node/68fee2c3-fc73-4b4e-9a47-2e8d6d512b95
#curl -L http://127.0.0.1:2379/v2/keys/service_images/awe-client/shock -XPUT -d value="shock.metagenomics.anl.gov/node/ec22ed3b-2b27-45e7-b5e8-d3896dd32a9d"
curl -L http://127.0.0.1:2379/v2/keys/service_images/awe-client/shock -XPUT -d value="shock.metagenomics.anl.gov/node/f2b11496-5f0e-4d7e-81c1-55322254d9a8"

# latest pipeline
#shock.metagenomics.anl.gov/node/021bf265-0c5b-4199-bfbb-90fc3feac527

# test pipeline
#shock.metagenomics.anl.gov/node/7e563784-6286-48e2-9773-496e0899b569

####### not production #######

#mysql_replica_metadata
#curl -L http://127.0.0.1:2379/v2/keys/service_images/mysql_replica_metadata/shock -XPUT -d value="shock.metagenomics.anl.gov/node/959090d2-172b-4f12-a10c-4907cff3cd96"

#mysql_galera_metadata
#curl -L http://127.0.0.1:2379/v2/keys/service_images/mysql_galera_metadata/shock -XPUT -d value="shock.metagenomics.anl.gov/node/758776ff-c4dc-45ee-8e0b-9d9786467876"

#opscenter server
#curl -L http://127.0.0.1:2379/v2/keys/service_images/opscenter/shock -XPUT -d value="shock.metagenomics.anl.gov/node/a030ea5b-3971-43c6-8574-6f82c510fca2"
