

# Solr metagenome

Build image:
```bash
docker build --tag=mgrast/solr-metagenome:`date +"%Y%m%d.%H%M"` https://raw.githubusercontent.com/MG-RAST/MG-RAST-infrastructure/master/services/solr-metagenome/docker/Dockerfile
```

After building the image using the Dockerfile in this repo you can start it like this:

```bash
sudo docker run -t -i -v /media/ephemeral/solr-metagenome/:/mnt -p 8983:8983 mgrast/solr-metagenome
```

You can either a) load the database using the Makefile or b) use an existing solr dump. In both cases check and adapt parameters in the Makefile, e.g. M5NR Version and shock node url if you want to use the cached solr database.

a) Loading from scratch:
```bash
MG-RAST-infrastructure/services/solr-metagenome/???
```
b) Deploy cached solr database: 
```bash
MG-RAST-infrastructure/services/solr-metagenome/download-solr-index.sh
```

Start solr:
```bash
MG-RAST-infrastructure/services/solr-metagenome/run-solr.sh
```
