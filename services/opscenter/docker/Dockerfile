# opscenter

FROM ubuntu:15.10

ENV VERSION 5.2.4
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
