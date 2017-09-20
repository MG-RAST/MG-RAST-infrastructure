
FROM debian:jessie

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y ganglia-monitor ganglia-monitor-python

# modify diskstat.py to use /host_proc instead of /proc
RUN sed -i -e "s:'/proc/:'/host_proc/:" /usr/lib/ganglia/python_modules/diskstat.py

# delete other python modules (one or more are crashing gmond)
RUN ls -1 /etc/ganglia/conf.d/*  | grep -v diskstat.pyconf | xargs rm

RUN sed -i -e "s/value = .*/value = 'md0 sda sdb sdc sdd'/" /etc/ganglia/conf.d/diskstat.pyconf


EXPOSE 8649
CMD ["/usr/sbin/gmond"]
