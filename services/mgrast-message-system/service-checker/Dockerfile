
# docker build -t mgrast/service-checker .
# development:  docker run -ti --name service-checker --net=${MMS_NETWORK} --rm  -v `pwd`/service-checker.pl:/service-checker.pl -v ${MMS_CONFIG_FILE}:/config.yml:ro mgrast/service-checker /bin/bash

FROM debian:jessie

RUN apt-get update && apt-get install -y \
  build-essential \
  libdbi-perl \
  libwww-perl \
  libdbd-mysql-perl \
  liblog-log4perl-perl \
  libyaml-tiny-perl \
  libjson-perl \
  cpanminus

RUN cpanm --force Net::RabbitMQ
RUN cpanm --force MongoDB

COPY ./service-checker.pl /service-checker.pl