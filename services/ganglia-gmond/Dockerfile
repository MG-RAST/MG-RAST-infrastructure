
FROM debian:jessie

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y ganglia-monitor ganglia-monitor-python

EXPOSE 8649
CMD ["/usr/sbin/gmond"]
