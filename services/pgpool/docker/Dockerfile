FROM ubuntu:15.10

RUN apt-get update && apt-get install -y build-essential libpq-dev curl vim

RUN curl -s -L http://www.pgpool.net/download.php?f=pgpool-II-3.5.0.tar.gz | tar -xvfz

RUN cd /pgpool-II-3.5.0 && \
  ./configure && \
  make && \
  make install

RUN rm -rfv /pgpool-II-3.5.0

RUN mkdir -p /var/log/pgpool /var/run/pgpool