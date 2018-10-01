# confd

# docker build -t mgrast/confd .
# docker run -ti --rm mgrast/confd ash



# !!!! keep the nginx version in sync with confd and nginx fleet units !!!!
FROM nginx:1.15.4 


ADD https://github.com/kelseyhightower/confd/releases/download/v0.16.0/confd-0.16.0-linux-amd64 /usr/bin/confd
RUN chmod +x /usr/bin/confd

ADD reload_nginx.sh	run_confd.sh /usr/bin/
