
# M5NR Solr

FROM ubuntu:14.10

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
  git clone https://github.com/MG-RAST/myM5NR.git && \
  source /myM5NR/solr/deployment.cfg && \
  mkdir -p /opt && \
  curl -s http://apache.mirrors.hoobly.com/lucene/solr/${SOLR_VERSION}/solr-${SOLR_VERSION}.tgz | tar -zxvf - -C /opt/ && \
  ln -s /opt/solr-${SOLR_VERSION} /opt/solr

# configure solr
RUN cd /myM5NR/solr && ./setup-m5nr-core.sh



EXPOSE 8983

