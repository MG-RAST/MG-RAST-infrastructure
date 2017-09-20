
# docker build -t mgrast/mms-email .

FROM alpine:3.6


RUN apk update && apk add python3
RUN pip3 install --upgrade pip && pip3 install pyyaml pika


COPY ./mms-email.py /