
# docker build -t mgrast/mms-email .
# development:  docker run -ti --name mms-email --net=${MMS_NETWORK} --rm  -v `pwd`/mms-email.py:/mms-email.py -v ${MMS_CONFIG_FILE}:/config.yml:ro mgrast/mms-email

FROM alpine:3.6


RUN apk update && apk add python3
RUN pip3 install --upgrade pip && pip3 install pyyaml pika


COPY ./mms-email.py /