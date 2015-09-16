# cassandra

FROM ubuntu:14.10

ENV CASSANDRA_VERSION 2.1.9
ENV CASSANDRA_URL http://apache.mirrors.ionfish.org/cassandra/${CASSANDRA_VERSION}/apache-cassandra-${CASSANDRA_VERSION}-bin.tar.gz

ENV AGENT_VERSION 5.2.0
ENV AGENT_URL http://downloads.datastax.com/community/datastax-agent-${AGENT_VERSION}.tar.gz

ENV AGENT_BIN /opt/agent/bin
ENV CASSANDRA_HOME /opt/cassandra
ENV CASSANDRA_BIN ${CASSANDRA_HOME}/bin
ENV CASSANDRA_CONFIG ${CASSANDRA_HOME}/conf
ENV OPTIONAL_CONFIG /config

# dependencies
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y curl python software-properties-common debconf-utils && \
    add-apt-repository -y ppa:webupd8team/java && \
    apt-get update && \
    echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | debconf-set-selections && \
    echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 seen true" | debconf-set-selections && \
    apt-get install -y oracle-java8-installer && \
    apt-get clean

RUN mkdir -p /opt /data /bin && \
    cd /bin && \
    curl -s -O https://raw.githubusercontent.com/MG-RAST/MG-RAST-infrastructure/master/services/cassandra/load-cassandra-m5nr.sh && \
    chmod +x load-cassandra-m5nr.sh && \
    curl -s -O https://raw.githubusercontent.com/MG-RAST/MG-RAST-infrastructure/master/services/cassandra/docker/docker-entrypoint.sh && \
    chmod +x docker-entrypoint.sh

RUN curl -s $CASSANDRA_URL | tar -zxvf - -C /opt && \
    ln -s /opt/apache-cassandra-${CASSANDRA_VERSION} /opt/cassandra

RUN curl -s $AGENT_URL | tar -zxvf - -C /opt && \
    ln -s /opt/datastax-agent-${AGENT_VERSION} /opt/agent

VOLUME /var/lib/cassandra

ENTRYPOINT ["/bin/docker-entrypoint.sh"]

# 7000: intra-node communication
# 7001: TLS intra-node communication
# 7199: JMX
# 9042: CQL
# 9160: thrift service
# 61621: opscenter agent communication
EXPOSE 7000 7001 7199 9042 9160 61621

CMD ["cassandra", "-f"]
