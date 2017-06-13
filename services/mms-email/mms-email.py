#!/usr/bin/env python3

# this is a simple RabbitMQ to Email connector

import smtplib, yaml, sys
from yaml import load
from email.mime.text import MIMEText
import pika
import json
import time




# get config
stream = open('/config/config.yml', 'r') 
conf = yaml.load(stream)
 
if not "email" in conf:
     sys.exit(1)

email_config = conf["email"]
email_server = email_config['server']
email_to = email_config['to']
email_from = email_config['from']

# ------------------------------------------


def send_email(subject, msg_text):
    
    global email_from
    global email_to
    global email_server
    
    msg = MIMEText(msg_text)
    
    msg['Subject'] = subject
    msg['From'] = email_from
    msg['To'] = email_to
    
    
    # Send message via SMTP server.
    s = smtplib.SMTP(email_server)
    s.send_message(msg)
    s.quit()
    


# ------------------------------------------


if not "rabbitmq" in conf:
     sys.exit(1)

rabbitmq = conf["rabbitmq"]

rabbitmq_user = rabbitmq['user']
rabbitmq_password = rabbitmq['password']


# setup RabbitMQ connection

credentials = pika.PlainCredentials(rabbitmq_user, rabbitmq_password)
 
connection = pika.BlockingConnection(pika.ConnectionParameters(host='rabbitmq', credentials=credentials))
 
channel = connection.channel()
queue_name ='email_outgoing'
channel.queue_declare(queue=queue_name)

 
 
while True:
    
    method_frame, header_frame, body = channel.basic_get(queue = queue_name, no_ack=False)
    if method_frame:
        print(method_frame, header_frame, body)
        print(body)
        try:
            channel.basic_ack(method_frame.delivery_tag)
        except exception as e:
            print("error: %s" % str(e), file=sys.stderr)
            time.Sleep(1)
            continue
            
        body_dict = json.loads(body)
    
        if 'event_type' in body_dict:
            event_type = body_dict['event_type']
            if event_type != "email":
                print("error: event_type unknown, email expexted, got %s" % event_type, file=sys.stderr)
                time.Sleep(1)
                continue
        else:
            print("error: event_type unknown, service_test expexted, got nothing")
            time.Sleep(1)
            continue
        
        if not "subject" in event:
            print("error: email subject missing", file=sys.stderr)
            time.Sleep(1)
            continue
        
        if not "message" in event:
            print("error: email message missing", file=sys.stderr)
            time.Sleep(1)
            continue
            
        subject = event["subject"]
        message = event["message"]
        
        try:
            send_email(subject, message)
        except Exception as e:
            print("error: send_email: %s" % (str(e)), file=sys.stderr)




