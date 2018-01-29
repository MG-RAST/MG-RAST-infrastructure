#!/usr/bin/env python3



import yaml, sys
from yaml import load
import pika
import json
import time
import dateutil.parser
import datetime
from datetime import timezone



debug = 1

connection=None
channel=None
credentials = None
#pika.PlainCredentials(rabbitmq_user, rabbitmq_password)


error_mode = False
last_error_message_sent=None

current_status={}

sent_after_2min=0
sent_after_10min=0
sent_after_1h=0
sent_after_3h=0


def makeChannel():
    global channel
    global connection
    
    success = 0
    while success == 0:
        try:
            channel = connection.channel()
        except pika.exceptions.ConnectionClosed:
            makeConnection()
            time.sleep(1)
            continue
            
        except Exception as ex:
            template = "An exception of type {0} occurred. Arguments:\n{1!r}"
            message = template.format(type(ex).__name__, ex.args)
            print("error in connection.channel(): {}".format(message))
            time.sleep(3)
            continue
        success = 1
        
    return
    

def makeConnection():
    global connection
    global credentials
    success = 0
    while success == 0:
        try:
            connection = pika.BlockingConnection(pika.ConnectionParameters(host='rabbitmq', credentials=credentials))
        except Exception as e:
            print("errorin getting connection: {}".format(str(e)), file=sys.stderr)
            time.sleep(5)
            continue
            
        success = 1
        if debug:
            print("connection build")
        
    return

def send_message(subject, msg):
    global connection
    
    event={}
    event["event_type"] = "email"
    event["subject"] = subject
    event["message"] = msg
    event["time"] = datetime.datetime.utcnow().isoformat()+'Z'
    event_json = json.dumps(event)
  
    
    success = 0
    
    while success == 0:
        
        #channel = connection.channel()
        queue_name ='email_outgoing'
        channel.queue_declare(queue=queue_name)
    
        print("sending to %s queue: %s" % (queue_name, event_json))
    
        try:
            channel.basic_publish(exchange='',
                                  routing_key=queue_name,
                                  body=event_json)
            connection.close()
        except Exception as e:
            print("error in basic_publish: %s" % str(e), file=sys.stderr)
            makeConnection()
            time.sleep(3)
            continue
            
        
    
        
        success = 1
        

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

makeConnection()
makeChannel()    
  


queue_name ='event_service_test'
channel.queue_declare(queue=queue_name)
channel.queue_purge(queue=queue_name)  

error_counts={}
 
count = 0 
while True:
    
    method_frame = None
    header_frame = None
    body = None
    
    # get message
    try:
        method_frame, header_frame, body = channel.basic_get(queue = queue_name, no_ack=False)
    except pika.exceptions.ChannelClosed:
        print("ChannelClosed. Retry to create channel...")
        makeChannel()
        
        continue
    except Exception as e:
        template = "An exception of type {0} occurred. Arguments:\n{1!r}"
        error_message = template.format(type(e).__name__, e.args)
        print("error in basic_get: %s" % (error_message), file=sys.stderr)
        time.sleep(1)
        makeConnection()
        continue
    
    if not method_frame:
        continue
        
    count+=1
    
    if debug:
        print("method_frame, header_frame: {} {}".format(method_frame, header_frame))
        print(body)
        
    # confirm receipt
    try:
        channel.basic_ack(method_frame.delivery_tag)
    except Exception as e:
        print("error: %s" % str(e), file=sys.stderr)
        time.Sleep(1)
        continue
        
    
    # parse message json
    body_dict = None
    try:
        body_dict = json.loads(body)
    except Exception as e:
        print("error: json.loads failed: {}".format(str(e)), file=sys.stderr)
        time.Sleep(1)
        continue
    
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
    
    # Compare time of event with current time
    event_time_str = body_dict['time']
    event_time = dateutil.parser.parse(event_time_str)
    
    current_time = datetime.datetime.now(timezone.utc)
    
    
    elapsed = current_time-event_time
    elapsed_seconds = elapsed.total_seconds()
    
    #print("event time: %s\n" % str(event_time))
    #print("current time: %s\n" % str(current_time))
    #print("elapsed time in seconds: %d\n" % elapsed_seconds)
    
    # discard old events
    if elapsed_seconds > 20:
        print("skipping message, too old")
        # TODO store in database ???
        continue
    
    if not 'service' in body_dict:
        print("service name missing", file=sys.stderr)
        continue
        
    service_name = body_dict['service']
    success = 0
   
    
    
    if 'success' in body_dict:        
        success = body_dict['success']
        
    
    
    current_status[service_name] = body_dict
    
    print(json.dumps(current_status, sort_keys=True, indent=4, separators=(',', ': ')))
    
    
    if not service_name in error_counts:
        error_counts[service_name] = {}
    
    
    
    
            
    if success:
        # reset counter
        error_counts[service_name]['count'] = 0
        
        if not error_mode:
            continue
        
        # check if there still are any errors remaining
        services_with_error= 0
        for key, val in error_counts.items():
            if 'count' in val:
                services_with_error += val['count']
        
        if services_with_error == 0:
            error_mode = False
            sent_after_2min=0
            sent_after_10min=0
            sent_after_1h=0
            sent_after_3h=0
            
            email_message = "no errors have been reported\n"
            print("message to send: {}".format(email_message))
            if do_send_message:
                send_message("all services operational", email_message)
        
        continue
        
        
    
    # success is False    
    error_mode = True
    
    if not 'count' in error_counts[service_name]:
        error_counts[service_name]['count'] = 0
    
    # increment counter
    error_counts[service_name]['count'] += 1
    
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
    
    
    
    print("message to send:\n{}".format(email_message))
    if do_send_message:
        send_message("service error", email_message)
    last_error_message_sent = datetime.datetime.now(timezone.utc)
        
    
    #continue
            
    # back to operational state: if there has not been any error for some time, reset last_error_message_sent timer
    #if last_error_message_sent:
    #    seconds_since_last_message = (current_time-last_error_message_sent).total_seconds()
    #    if seconds_since_last_message > 5*60:
    #        last_error_message_sent = None
    #        
    #        last_error_message_sent = None
    #        continue
            
    


