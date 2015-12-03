# image to run nginx and confd containers (one container for each)

FROM nginx 
# baseimage is offical nginx release

RUN apt-get update && apt-get -y install git curl net-tools

# config files and run_confd.sh
RUN cd / && \
  git clone https://github.com/MG-RAST/MG-RAST-infrastructure.git && \
  mkdir -p /etc/nginx/sites-enabled/

# install confd (docker required to reload nginx in separate nginx container)
ADD https://github.com/kelseyhightower/confd/releases/download/v0.11.0/confd-linux-amd64 /usr/bin/confd
ADD https://get.docker.com/builds/Linux/x86_64/docker-1.7.1 /usr/bin/docker
RUN chmod +x /usr/bin/confd /usr/bin/docker


# Expose nginx ports.
EXPOSE 80
EXPOSE 443
