
# docker build -t mgrast/cassandra:3.10 .


FROM cassandra:3.11

COPY docker-entrypoint.sh /docker-entrypoint.sh

COPY cassandra-env.sh /etc/cassandra

COPY logback.xml /etc/cassandra

COPY cqlshrc /root/.cassandra/

