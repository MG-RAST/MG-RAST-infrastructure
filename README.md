# MG-RAST-infrastructure


## Example deployment process for a fleet service using skycore
Build image (requires docker):
```bash
export TAG=`date +"%Y%m%d.%H%M"`
docker build --tag=mgrast/m5nr-solr:${TAG} --force-rm --no-cache https://raw.githubusercontent.com/MG-RAST/myM5NR/master/solr/docker/Dockerfile
```
Upload image to Shock:
```bash
skycore push mgrast/m5nr-solr:${TAG}
or
skycore push --shock=http://shock.metagenomics.anl.gov --token=$TOKEN mgrast/m5nr-solr:${TAG}
```
Register shock node (of the new image) with etcd (requires etcd access):
```bash
curl -L http://127.0.0.1:4001/v2/keys/service_images/m5nr-solr/shock -XPUT -d value="shock.metagenomics.anl.gov/node/<node_id>"
```
Please update/add the corresponding line register_docker_image_for_service_all.sh .

Note: You can read the current configuration with the same url:
```bash
curl -L http://127.0.0.1:4001/v2/keys/service_images/<servicename>/shock
```

And restart fleet service... either with fleetctl or fleet api..
```bash
fleetctl start xyz@1.service
```


