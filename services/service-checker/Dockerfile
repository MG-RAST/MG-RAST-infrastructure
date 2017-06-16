
# docker build -t mgrast/service-checker .
# docker run -ti --name service-checker mgrast/service-checker /bin/bash


FROM debian:jessie

RUN apt-get update && apt-get install -y \
  libdbi-perl \
  libmongodb-perl \
  libwww-perl \
  libdbd-pg-perl \
  libdbd-mysql-perl \
  libmongodb-perl \
  liblog-log4perl-perl \
  libyaml-tiny-perl \
  libnet-smtp-ssl-perl \
  libjson-perl \
  libfile-slurp-perl \
  cpanminus \
  build-essential

RUN cpanm --force Net::RabbitMQ

COPY ./service-checker.pl /service-checker.pl