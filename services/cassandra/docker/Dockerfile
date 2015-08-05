# cassandra

FROM ubuntu:14.10

ENV CASSANDRA_VERSION 2.1.8
ENV CASSANDRA_URL http://apache.cs.utah.edu/cassandra/${CASSANDRA_VERSION}/apache-cassandra-${CASSANDRA_VERSION}-bin.tar.gz

ENV AGENT_VERSION 5.2.0
ENV AGENT_URL http://downloads.datastax.com/community/datastax-agent-${AGENT_VERSION}.tar.gz

ENV AGENT_BIN /opt/agent/bin
ENV CASSANDRA_BIN /opt/cassandra/bin
ENV CASSANDRA_CONFIG /opt/cassandra/conf
ENV OPTIONAL_CONFIG /config

# dependencies
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
        curl \
        python \
        default-jre \
        default-jdk && \
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
    ln -s /opt/datastax-agent-${AGENT_VERSION} /opt/agent && \
    cd /opt/agent/conf && \
    rm -f address.yaml && \
    curl -s -O https://raw.githubusercontent.com/MG-RAST/MG-RAST-infrastructure/master/services/opscenter/address.yaml

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
