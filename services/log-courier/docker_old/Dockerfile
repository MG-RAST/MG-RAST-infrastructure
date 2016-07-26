FROM ubuntu:14.04 

RUN apt-get update && apt-get install -y \
    golang \
    git \
    make \
    wget \
    supervisor && \
  mkdir -p /var/log/supervisor && \
  git clone https://github.com/driskell/log-courier && \
  cd log-courier && \
  make && \
  cp /log-courier/bin/log-courier /bin/ 

