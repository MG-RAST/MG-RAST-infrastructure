#!/usr/bin/env python3

import json
from pprint import pprint
import requests
import sys

def load_metagenome(id):
    r = requests.put('http://localhost:9200/metagenome_index/metagenome/'+id, data=data_json)
    response_obj = r.json()
    if response_obj["result"] == "created":
        print("success")
    else:
       print(r.text)

with open(sys.argv[1]) as data_file:    
    object = json.load(data_file)

#pprint(object)

data = object["add"]["doc"]
pprint(data)
id = data["id"]
print("id: %s" % (id))
data_json = json.dumps(data)




load_metagenome(id)

#PUT /{index}/{type}/{id}