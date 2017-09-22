# docker build -t mgrast/service-monitor .

FROM alpine:3.6


RUN apk update && apk add python3
RUN pip3 install --upgrade pip ; pip3 install pyyaml pika python-dateutil


COPY ./service-monitor.py /