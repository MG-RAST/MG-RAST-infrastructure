

## Fleet

	fleetctl list-units
	fleetctl list-machines
	fleetctl list-unit-files


### Start service:

If the fleet unit is not loaded already, go first into a directory that contains the fleet unit file. When you start the service it will be loaded from the file.

	fleetctl start mg-rast-v4-web{,-discovery}\@{1..2}.service

This starts two instances of a service together with their discovery units.

### Stop service:

	fleetctl stop mg-rast-v4-web{,-discovery}\@{1..2}.service

When you restart a service that you stopped earlier, it will be started on the same machine.

## Destroy service:

When you stop a service, the fleet unit definition is still loaded. To remove it, e.g. because you have a newer version that you want to use instead, run:

	fleetctl destroy mg-rast-v4-web{,-discovery}\@{1..2}.service


If you are on the machine that runs the service, you can also by-pass fleet by talking directly with systemd, e.g.:

	sudo systemctl status api-server@1.api
	sudo systemctl restart api-server@1.api


## Etcd

	etcdctl ls /
	etcdctl ls /services/
	etcdctl ls /services/api-server/
	etcdctl get /services/api-server/api/api-server@1.api


## Journal

You have to be local to the fleet unit:

	journalctl -b -u api-server@1.api | tail -n 100

