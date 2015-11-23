
# Metagenome Solr

FROM ubuntu:15.04

RUN apt-get update && apt-get upgrade -y && apt-get install -y \
        libtemplate-perl \
		git \
		curl \
		openjdk-8-jre \
		unzip \
		bc

RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# install solr
RUN cd / && \
  git clone https://github.com/MG-RAST/MG-RAST-infrastructure.git && \
  source /MG-RAST-infrastructure/services/solr-metagenome/deployment.cfg && \
  mkdir -p /opt && \
  curl -s http://archive.apache.org/dist/lucene/solr/${SOLR_VERSION}/solr-${SOLR_VERSION}.tgz | tar -zxvf - -C /opt/ && \
  ln -s /opt/solr-${SOLR_VERSION} /opt/solr

# configure solr
RUN cd /MG-RAST-infrastructure/services/solr-metagenome/ && ./setup-metagenome-core.sh

EXPOSE 8983
