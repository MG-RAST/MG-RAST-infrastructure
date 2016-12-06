
# docker build -t mgrast/cassandra:3.7 .


FROM cassandra:3.7

COPY docker-entrypoint.sh /docker-entrypoint.sh

COPY cassandra-env.sh /etc/cassandra

COPY logback.xml /etc/cassandra

COPY cqlshrc /root/.cassandra/

