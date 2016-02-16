FROM ubuntu:15.10

RUN apt-get update && apt-get install -y build-essential libpq-dev curl vim

RUN curl -s -L -o pgpool-II-3.5.0.tar.gz http://www.pgpool.net/download.php?f=pgpool-II-3.5.0.tar.gz && \
  tar zxvf pgpool-II-3.5.0.tar.gz

RUN cd /pgpool-II-3.5.0 && \
  ./configure && \
  make && \
  make install

RUN rm -rfv pgpool-II-3.5.0 pgpool-II-3.5.0.tar.gz

RUN mkdir -p /var/log/pgpool /var/run/pgpool /config

RUN ln -s /config/pgpool.conf /usr/local/etc/pgpool.conf