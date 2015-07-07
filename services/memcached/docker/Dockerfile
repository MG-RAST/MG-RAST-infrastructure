# memcached

FROM ubuntu:14.10

RUN groupadd -r memcache && useradd -r -g memcache memcache

RUN apt-get update && apt-get install -y memcached

# remove default daemon state
RUN sed -i 's;^\-d;# -d;' /etc/memcached.conf

EXPOSE 11211

USER memcache
