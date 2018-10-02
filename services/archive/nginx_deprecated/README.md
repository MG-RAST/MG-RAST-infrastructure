
The image contains both nginx and confd, but they will be executed in separate containers.

For instructions to build this image see build.sh.

### Start nginx
```bash
docker run -d -p 80:80 -v /etc/nginx/sites-enabled/ --name mgrast_nginx mgrast/nginxconfd /usr/sbin/nginx -c /MG-RAST-infrastructure/services/nginx/nginx.conf
```
Or alternatively with latest git code:
```bash
docker run -d -p 80:80 -v /etc/nginx/sites-enabled/ --name mgrast_nginx mgrast/nginxconfd bash -c 'cd MG-RAST-infrastructure && git pull && /usr/sbin/nginx -c /MG-RAST-infrastructure/services/nginx/nginx.conf'
```

### Start confd
```bash
docker run -t -i --volumes-from mgrast_nginx -v /var/run/docker.sock:/var/run/docker.sock --name mgrast_confd mgrast/nginxconfd /MG-RAST-infrastructure/services/nginx/confd/run_confd.sh
```
Or alternatively with latest git code:
```bash
docker run -t -i --volumes-from mgrast_nginx -v /var/run/docker.sock:/var/run/docker.sock --name mgrast_confd mgrast/nginxconfd bash -c 'cd MG-RAST-infrastructure && git pull && /MG-RAST-infrastructure/services/nginx/confd/run_confd.sh'
```

### Issues
confd uses here docker to invoke a reload of nginx in the nginx container. This requires that the docker client is the same version as the host docker server.
