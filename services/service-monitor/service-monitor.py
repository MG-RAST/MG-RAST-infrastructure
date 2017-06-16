#!/usr/bin/env python3



import yaml, sys
from yaml import load
import pika
import json
import time
import dateutil.parser
import datetime
from datetime import timezone




last_error_message_sent=None

current_status={}

sent_after_2min=0
sent_after_10min=0
sent_after_1h=0
sent_after_3h=0

def send_message(subject, msg):
    credentials = pika.PlainCredentials(rabbitmq_user, rabbitmq_password)
 
    connection = pika.BlockingConnection(pika.ConnectionParameters(host='rabbitmq', credentials=credentials))
 
    channel = connection.channel()
    queue_name ='email_outgoing'
    channel.queue_declare(queue=queue_name)
    
    event={}
    event["event_type"] = "email"
    event["subject"] = subject
    event["message"] = msg
    
    event_json = json.dumps(event)
    
    print("sending to %s queue: %s" % (queue_name, event_json))
    
    channel.basic_publish(exchange='',
                          routing_key=queue_name,
                          body=event_json)
    connection.close()
    
    global last_error_message_sent
    
    last_error_message_sent = datetime.datetime.now(timezone.utc)


# get config
stream = open('/config/config.yml', 'r') 
conf = yaml.load(stream)
 
if not "email" in conf:
     sys.exit(1)

email = conf["email"]
 

if not "rabbitmq" in conf:
     sys.exit(1)

rabbitmq = conf["rabbitmq"]

rabbitmq_user = rabbitmq['user']
rabbitmq_password = rabbitmq['password']


# setup RabbitMQ connection

credentials = pika.PlainCredentials(rabbitmq_user, rabbitmq_password)
 
connection = pika.BlockingConnection(pika.ConnectionParameters(host='rabbitmq', credentials=credentials))
 
channel = connection.channel()
queue_name ='event_service_test'
channel.queue_declare(queue=queue_name)


error_counts={}
 
count = 0 
while True:
    method_frame, header_frame, body = channel.basic_get(queue = queue_name, no_ack=False)
    if not method_frame:
        continue
    
    count+=1
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
        if event_type != "service_test":
            print("error: event_type unknown, service_test expexted, got %s" % event_type, file=sys.stderr)
            time.Sleep(1)
            continue
    else:
        print("error: event_type unknown, service_test expexted, got nothing", file=sys.stderr)
        time.Sleep(1)
        continue
            
    event_time_str = body_dict['time']
    event_time = dateutil.parser.parse(event_time_str)
    current_time = datetime.datetime.now(timezone.utc)
    
    elapsed = current_time-event_time
    elapsed_seconds = elapsed.total_seconds()
    
    print("event time: %s\n" % str(event_time))
    print("current time: %s\n" % str(current_time))
    print("elapsed time in seconds: %d\n" % elapsed_seconds)
    
    if elapsed_seconds > 20:
        # TODO store in database ???
        continue
    
    if not 'service' in body_dict:
        print("service name missing", file=sys.stderr)
        continue
        
    service = body_dict['service']
    success = 0
    error = 0
    
    if 'error' in body_dict:
        error = body_dict['error']
    
    if 'success' in body_dict:
        
        # test errors
        #if count % 5 == 0 :
        #    body_dict['success'] = 0
        
        success = body_dict['success']
        
    
    
    current_status[service] = body_dict
    
    print(json.dumps(current_status, sort_keys=True, indent=4, separators=(',', ': ')))
    
    
    if not service in error_counts:
        error_counts[service] = {}
    
    service_error_counts = error_counts[service]
    
   
    
    
    
            
    if success:
        # reset counter
        service_error_counts['count'] = 0
        
        sent_after_2min=0
        sent_after_10min=0
        sent_after_1h=0
        sent_after_3h=0
        
    else:
        if not 'count' in service_error_counts:
            service_error_counts['count'] = 0
        
        # increment counter
        service_error_counts['count'] += 1
        
        do_send_message = 0
        if last_error_message_sent:
            seconds_since_last_message = (current_time-last_error_message_sent).total_seconds()
            
            if seconds_since_last_message >= 2*60 and seconds_since_last_message < 10*60 and sent_after_2min == 0:
                do_send_message = 1
                sent_after_2min = 1
            elif seconds_since_last_message >= 10*60 and seconds_since_last_message < 60*60 and sent_after_10min == 0:
                do_send_message = 1
                sent_after_10min = 1
            elif seconds_since_last_message >= 60*60 and seconds_since_last_message < 3*60*60 and sent_after_1h == 0:
                do_send_message = 1
                sent_after_1h = 1
            elif seconds_since_last_message >= 3*60*60: # send message every 3 hours
                do_send_message = 1
                sent_after_3h = 1
                
            
        else:
            do_send_message = 1
            seconds_since_last_message = 0
        
        
            
        if do_send_message:
            email_message = ""
            for s_name, s in current_status.items():
                state = "ok   "
                if "error" in s:
                    state = s['error']
                line = ""
                line += s_name
                "{:<12}".format(line)
                
                line += ": %s" % (state)
                
                if 'message' in s:
                    line += "\n     details: %s" % (s['message'])
                    
                email_message += line+"\n"
            
            
            print("email_message: %s" % (email_message))
            send_message("service error", email_message)
        
        continue
            
    # back to operational state: if there has not been any error for some time, reset last_error_message_sent timer
    if last_error_message_sent:
        seconds_since_last_message = (current_time-last_error_message_sent).total_seconds()
        if seconds_since_last_message > 5*60:
            last_error_message_sent = None
            email_message = "no errors have been reported\n"
            send_message("all services operational", email_message)
            continue
            
    


