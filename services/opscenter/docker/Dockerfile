# opscenter

FROM ubuntu:14.10

ENV VERSION 5.1.3
ENV URL http://downloads.datastax.com/community/opscenter-${VERSION}.tar.gz

# dependencies
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
        curl \
        python && \
    apt-get clean

RUN mkdir -p /opt && \
    curl -s $URL | tar -zxvf - -C /opt && \
    ln -s /opt/opscenter-${VERSION} /opt/opscenter

EXPOSE 8888 61620
