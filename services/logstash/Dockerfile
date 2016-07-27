

FROM logstash:2.3.4-1
#FROM logstash:1.5.4-1


RUN cd /opt/logstash && bin/logstash-plugin install logstash-input-courier
RUN cd /opt/logstash && bin/logstash-plugin install logstash-output-courier

RUN sed -i -e "s:\['_source'\]:['@timestamp', 'loglevel' , 'unit', 'journald._COMM', 'host', 'logformat', 'message']:" /opt/kibana/src/plugins/kibana/public/discover/controllers/discover.js

