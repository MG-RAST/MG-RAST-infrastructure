
FROM debian:jessie

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y ganglia-monitor ganglia-monitor-python

# modify diskstat.py to use /host_proc instead of /proc
RUN sed -i -e "s:'/proc/:'/host_proc/:" /usr/lib/ganglia/python_modules/diskstat.py


EXPOSE 8649
CMD ["/usr/sbin/gmond"]
