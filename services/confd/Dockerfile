# confd

# docker build -t mgrast/confd .
# docker run -ti --rm mgrast/confd ash

FROM alpine

ADD https://github.com/kelseyhightower/confd/releases/download/v0.16.0/confd-0.16.0-linux-amd64 /usr/bin/confd
RUN chmod +x /usr/bin/confd

ADD *.sh /usr/bin/
