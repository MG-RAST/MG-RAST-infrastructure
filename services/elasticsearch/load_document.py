#!/usr/bin/env python3

import json
from pprint import pprint
import requests
import sys
import os


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
    url = "http://api-dev.metagenomics.anl.gov/job/solr" 
    data  = { "metagenome_id": id,
            "debug": 1,
            "rebuild": 1,
            "sync": 1 }
    headers = { "Authorization" : "mgrast "+os.environ['MGRKEY'] }
    r = requests.post( url , headers=headers, json = data)
    return r


#load document into ES
def load_document(_id, data):
    url = es_url +'/metagenome_index/metagenome/' + _id
    print(url)
   
    r = requests.put(url, data=data)
    response_obj = r.json()
    if not "result" in response_obj:
        print(r.text)
        sys.exit(1)
    
    if response_obj["result"] == "created":
        print("success")
    else:
       print(r.text)


for id_requested in ["mgm4441680.3"]:
    
   
    if es_find_document(id_requested):
        print("%s already found, skipping..." % (id_requested))
        continue
    else:
        print("Getting %s from API..." % (id_requested))


    r = read_metagenome(id_requested)
    r_obj = r.json()


    
    #with open(sys.argv[1]) as data_file:
    #    r_obj = json.load(data_file)


    #pprint(object)

    data = r_obj["data"]

    #pprint(data)
    id_returned = data["id"]

    if id_requested != id_returned:
        print("id_requested: %s     id_returned %s\n" % (id_requested, id_returned))
        sys.exit(1)


    print("load metagenome %s into ES..." % (id_requested))
    load_document(id_requested, data)

    #PUT /{index}/{type}/{id}