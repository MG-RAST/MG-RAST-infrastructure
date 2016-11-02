#!/usr/bin/env python3

import json
from pprint import pprint
import requests
import sys
import os

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
    url = "http://api-dev.metagenomics.anl.gov/job/solr" 
    data  = { "metagenome_id": id,
            "debug": 1,
            "rebuild": 1,
            "sync": 1 }
    headers = { "Authorization" : "mgrast "+os.environ['MGRKEY'] }
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
        sys.exit(1)
    
    if response_obj["result"] == "created":
        print("success")
    else:
       print(r.text)


def fix_document(data):
    
    if "collection_date" in data:
        collection_date = data["collection_date"]
        
        print("collection_date: %s" % (collection_date))
    
        # remove UTC suffix
        if collection_date.endswith(' UTC'):
            collection_date = collection_date[:-4]
    
        # replace space with T after date
        if len(collection_date) >= 11:
            if collection_date[10] == " ":
                collection_date=collection_date[:10]+"T"+collection_date[11:]
    
        data["collection_date"] = collection_date

def transfer_document(transfer_id):
    if es_find_document(transfer_id):
        print("%s already found, skipping..." % (transfer_id))
        return
    else:
        print("Getting %s from API..." % (transfer_id))


    r = read_metagenome(transfer_id)
    r_obj = r.json()


    
    #with open(sys.argv[1]) as data_file:
    #    r_obj = json.load(data_file)
    with open('temp_file.txt', 'w') as f:
        f.write(r.text)

    #pprint(object)

    data = r_obj["data"]

    fix_document(data)

    #pprint(data)
    id_returned = data["id"]

    if transfer_id != id_returned:
        print("id_requested: %s     id_returned %s\n" % (transfer_id, id_returned))
        sys.exit(1)


    print("load metagenome %s into ES..." % (transfer_id))
    load_document(transfer_id, data)






# You could also pass OAuth in the constructor
c = RestClient("http://api.metagenomics.anl.gov", headers = { "Authorization" : "mgrast "+os.environ['MGRKEY'] })

for elem in c.get_stream("/metagenome", params={"verbosity": "minimal"}):
    print(elem)
    transfer_document(elem["id"])
    
   
    

    #PUT /{index}/{type}/{id}