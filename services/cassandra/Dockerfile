
# docker build -t mgrast/cassandra:3.7 .


FROM cassandra:3.7

COPY docker-entrypoint.sh /docker-entrypoint.sh

COPY logback.xml /etc/cassandra

COPY cqlshrc /root/.cassandra/

