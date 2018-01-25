# docker build -t mgrast/service-monitor .
# development: docker run -ti --name service-monitor --net=${MMS_NETWORK} --rm -v `pwd`/service-monitor.py:/service-monitor.py -v ${MMS_CONFIG_FILE}:/config/config.yml:ro mgrast/service-monitor

FROM alpine:3.6


RUN apk update && apk add python3
RUN pip3 install --upgrade pip ; pip3 install pyyaml pika python-dateutil


COPY ./service-monitor.py /