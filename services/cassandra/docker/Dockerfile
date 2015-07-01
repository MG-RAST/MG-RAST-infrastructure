# cassandra

FROM ubuntu:14.10

ENV CASS_VERSION 2.1.7
ENV CASS_URL http://psg.mtu.edu/pub/apache/cassandra/${CASS_VERSION}/apache-cassandra-${CASS_VERSION}-bin.tar.gz

ENV AGENT_VERSION 5.1.3
ENV AGENT_URL http://downloads.datastax.com/community/datastax-agent-${AGENT_VERSION}.tar.gz

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
  curl -s -O https://raw.githubusercontent.com/MG-RAST/MG-RAST-infrastructure/master/services/cassandra/configure-cassandra.sh && \
  chmod +x configure-cassandra.sh && \
  curl -s -O https://raw.githubusercontent.com/MG-RAST/MG-RAST-infrastructure/master/services/cassandra/load-cassandra-m5nr.sh && \
  chmod +x load-cassandra-m5nr.sh

RUN curl -s $CASS_URL | tar -zxvf - -C /opt && \
    ln -s /opt/apache-cassandra-${CASS_VERSION} /opt/cassandra

RUN curl -s $AGENT_URL | tar -zxvf - -C /opt && \
    ln -s /opt/datastax-agent-${AGENT_VERSION} /opt/agent

EXPOSE 7000 7001 7199 9042 9160 61621
