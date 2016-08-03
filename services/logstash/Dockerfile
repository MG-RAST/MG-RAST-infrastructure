

FROM logstash:2.3.4-1
#FROM logstash:1.5.4-1


RUN cd /opt/logstash && bin/logstash-plugin install logstash-input-courier
RUN cd /opt/logstash && bin/logstash-plugin install logstash-output-courier

