#!/bin/sh

set -x 
set -e


# create shock config dir
mkdir /etc/shock

#copy shock config file
install -m555 shockd-mgrast.conf   /etc/shock

# copy init.d scripts
install -m555 shockd-functions /etc/rc.d/init.d/
install -m555 shockd-mgrast /etc/rc.d/init.d/



cd /etc/rc2.d
ln -s ../init.d/shockd-mgrast S98shockd-mgrast
