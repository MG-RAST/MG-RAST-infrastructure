#!/usr/bin/env python3

import json
from pprint import pprint
import requests
import sys
import os
import re

from restclient import RestClient

import iso8601

# pip3 install python-dateutil

# note: had to set /sites/1/MG-RAST/site/lib/MGRAST/Abundance.pm chunks from 2000 to 100 in the API

es_url = os.environ['ES_URL']


# query ES
def es_find_document(id):
    params = { "pretty" : True, "_source" : False}
    r = requests.get(es_url +'/metagenome_index/metagenome/'+id, params=params)
    #print(r.text)
    obj = r.json()
    return obj["found"]

# get document from MG-RAST API
def read_metagenome(id):
    url = "http://api-pql.metagenomics.anl.gov/job/solr" 
    data  = { "metagenome_id": id,
            "debug": 1,
            "rebuild": 1,
            "sync": 1 }
    headers = { "Authorization" : "mgrast "+os.environ['MGRKEY'] }
    
    
    print("curl -H \"Authorization: mgrast %s\" -d '%s' %s" % (os.environ['MGRKEY'], json.dumps(data), url))
    
    r = requests.post( url , headers=headers, json = data)
        
    return r


#load document into ES
def load_document(_id, data_dict):
    url = es_url +'/metagenome_index/metagenome/' + _id
    print(url)
   
    # comment: use json.dumps , see https://discuss.elastic.co/t/index-a-new-document/35281/8
    r = requests.put(url, data=json.dumps(data_dict))
    response_obj = r.json()
    if not "result" in response_obj:
        print(r.text)
        return False
    
    if response_obj["result"] == "created":
        print("success")
    else:
        print(r.text)
        return False
        
    return True

def fix_document(data):
    
    if "collection_date" in data:
        collection_date = data["collection_date"]
        
        print("collection_date: %s" % (collection_date))
    
        # remove UTC suffix
        if collection_date.endswith(' UTC'):
            collection_date = collection_date[:-4]
    
        regex = r"^(.*) UTC([+-]\d+)$"
        match = re.search(regex, collection_date)

        if match:
            collection_date_without_tz = match.group(1)
            timezone = match.group(2)
            
            collection_date = collection_date_without_tz+timezone
        
        # match single digit hour as timezone
        # example : collection_date = "2005-05-24T10:30:00-6"
        regex = r"^(.*)([+-])(\d)$"
        match = re.search(regex, collection_date)

        if match:
            collection_date_without_tz = match.group(1)
            tz_sign =  match.group(2)
            tz_hour = match.group(3)
            
            
            collection_date = collection_date_without_tz+tz_sign+"0"+tz_hour
        
    
        # replace space with T after date
        if len(collection_date) >= 11:
            if collection_date[10] == " ":
                collection_date=collection_date[:10]+"T"+collection_date[11:]
    
        data["collection_date"] = collection_date

def transfer_document(transfer_id):
    if es_find_document(transfer_id):
        print("%s already found, skipping..." % (transfer_id))
        return True
    else:
        print("Getting %s from API..." % (transfer_id))


    r = read_metagenome(transfer_id)
    
    with open('temp_file.txt', 'w') as f:
        f.write(r.text)
        
    try:
        r_obj = r.json()
    except Exception as e:
        print("Exception parsing json: %s" % (str(e)))
        return False

    

    if 'ERROR' in r_obj:
        print(r_obj)
        print("found ERROR\n")
        return False

    #pprint(object)
    if not "data" in r_obj:
        print(r_obj)
        print("data not in r_obj\n")
        return False

    data = r_obj["data"]

    fix_document(data)

    #pprint(data)
    if not "id" in data:
        print("id not in data\n")
        return False
        
    id_returned = data["id"]

    if transfer_id != id_returned:
        print("id_requested: %s     id_returned %s\n" % (transfer_id, id_returned))
        return False


    print("load metagenome %s into ES..." % (transfer_id))
    loading_ok = load_document(transfer_id, data)
    
    return loading_ok



# You could also pass OAuth in the constructor
c = RestClient("http://api.metagenomics.anl.gov", headers = { "Authorization" : "mgrast "+os.environ['MGRKEY'] })





result = c.get("/metagenome", params={"verbosity": "minimal"})

result_obj = result.json()

total_count = result_obj["total_count"]


success = 0
failure = 0
count = 0
for elem in c.get_stream("/metagenome", params={"verbosity": "minimal"}):
    count +=1
    print(elem)
    r = transfer_document(elem["id"])
    if r:
        success +=1
    else:
        failure += 1
        print("ERROR\n")
        
    print("%d / %d  (success: %d  , failure: %d)" % (count, total_count, success, failure))
    

    #PUT /{index}/{type}/{id}