
# docker built -t mgrast/event-loader


FROM debian:jessie


RUN apt-get update && apt-get install python3 python3-pip libmysqlclient-dev

RUN pip3 install flask flask-sqlalchemy mysqlclient sqlalchemy-utils


COPY ./event-loader.py /event-loader.py