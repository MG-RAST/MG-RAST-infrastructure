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

# You could also pass OAuth in the constructor
api = RestClient("http://api.metagenomics.anl.gov", headers = { "Authorization" : "mgrast "+os.environ['MGRKEY'] })


properties=None

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


# example: #http://api.metagenomics.anl.gov/metagenome/mgm4441680.3?verbosity=full
def read_metadata_from_api(id):
    result = api.get("metagenome/"+id, params={"verbosity": "full"}, debug=True)
    result_obj = result.json()
    
    # remove data we do not need
    statistics = result_obj["statistics"]
    
    del statistics["gc_histogram"]
    del statistics["length_histogram"]
    del statistics["taxonomy"]
    del statistics["source"]
    del statistics["rarefaction"]
    del statistics["qc"]
    del statistics["ontology"]
    del statistics["function"]
    
    return result_obj

#load document into ES
def load_document(data_dict):
    _id = data_dict['id']
    url = es_url +'/metagenome_index/metagenome/' + _id
    print(url)
   
    # comment: use json.dumps , see https://discuss.elastic.co/t/index-a-new-document/35281/8
    r = None
    try:
        r = requests.put(url, data=json.dumps(data_dict))
    except Exception as e:
        print("Exception loading into ES: %s" % (str(e)))
        return False
        
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


def transfer_document(transfer_id):
  
    api_data = None
    try:
        #r = transfer_document(elem["id"])
        
        if es_find_document(transfer_id):
            print("%s already found, skipping..." % (transfer_id))
            return True
        else:
            print("Getting %s from API..." % (transfer_id))
    except Exception as e:
         print("Exception es_find_document: %s" % (str(e)))
         return False
         
    try:
        api_data = read_metadata_from_api(transfer_id)

        print("***************** metadata from API:\n")
        pprint(api_data)
    except Exception as e:
        print("Exception read_metadata_from_api: %s" % (str(e)))
        return False
        
    es_document = None
    try:
            
        es_document = create_es_doc_from_api_doc(api_data)
    except Exception as e:
        print("Exception create_es_doc_from_api_doc: %s" % (str(e)))
        return False

    try:
        print("***************** metadata from API that is still missing:\n")
        pprint(api_data)

        
        print("***************** es_document:\n")
        pprint(es_document)

        # check what is missing
        for key, value in properties.items() :
            if not key in es_document:
                print("missing: %s" % key )

    except Exception as e:
        print("Exception transferring document A: %s" % (str(e)))
        return False
        
    try:

        print("***************** api_data after using data:\n")
        pprint(api_data)
        
    except Exception as e:
        print("Exception transferring document B: %s" % (str(e)))
        return False
    
    
    
    
    
    print("sending...")
    pprint(es_document)
    loading_ok = False
    try:
        loading_ok = load_document(es_document)
    except Exception as e:
      print("Exception transferring document B: %s" % (str(e)))
      return False
    
    return loading_ok


def fix_type(key, value, properties):


    if not key in properties:
        print("Warning: Adding unknown key \"%s\"" % (key) )
        return value
        
    try:    
        expected_type = properties[key]['type']
    except Exception as e:
        print(str(e))
        exit(1)
    
    this_type = type(value)
    
    if this_type == int:
        this_type_str="integer"
    elif this_type == str:
        this_type_str="string"
    else:
        print(str(this_type))
        exit(1)
        
    if expected_type=="integer" and this_type_str=="string":
        return int(value)
        
    if expected_type=="boolean" and this_type_str=="string":
        if value == "yes":
            return True
        elif value == "no":
            return False
        
        print(str(this_type))
        exit(1)
        
            
    if expected_type=="float" and this_type_str=="string":
        return float(value)
    
    if expected_type=="date" and this_type_str=="string":
        return value
        
    if this_type_str != expected_type:
        print("key: %s %s %s\n", key, expected_type, this_type_str )
        print("%s %s\n", key, value)
        exit(1)

    return value

                
                
def get_schema_properties():


    schema=None
    with open('metagenome_schema.json') as json_data:
        schema = json.load(json_data)
        pprint(schema)
    
    
        
    properties = schema["mappings"]["metagenome_metadata"]["properties"]
    return properties



def get_api_fields(es_document, section_name, section):
    
    
    for key in section.keys():
        if key in section and key != None:
            value = section[key]
            if type(value) == dict:
                continue
            new_value = fix_type(key, section[key], properties)
            if new_value:
                es_document[section_name+"_"+key]=new_value
            
        
    
    return


def create_es_doc_from_api_doc(api_data):
    es_document = {}
    
    try:
        api_project = api_data['project']
    except:
        api_project={}
        
        
    try:
        api_library = api_data['library']
    except:
        api_library = {}
        
        
    try:
        api_sample = api_data['sample']
    except:
        api_sample = {}
    
    try:
        api_pipeline_parameters = api_data['pipeline_parameters']
    except:
        api_pipeline_parameters ={}
        
    try:
        api_sequence_statistics = api_data['sequence_stats']
    except:
        api_sequence_statistics = {}
   
   

    ### job_info
    get_api_fields(es_document, 'job_info', api_data)
    
        
    if not 'job_info_public' in es_document:
        if 'job_info_status' in es_document:
            if es_document['job_info_status']== "public":
                es_document['job_info_public']=True
            else:
                es_document['job_info_public']=False
            del es_document['job_info_status']
        
            
            
    if api_project:
        get_api_fields(es_document, 'project' , api_project)
        
    if api_library:
        get_api_fields(es_document, 'library', api_library)
        
    if api_sample:
        get_api_fields(es_document, 'sample', api_sample)
        
    if api_pipeline_parameters:
        get_api_fields(es_document, 'pipeline_parameters', api_pipeline_parameters)
 
    if api_sequence_statistics:
        get_api_fields(es_document, 'sequence_statistics', api_sequence_statistics)
 

    if not 'job_info_id' in es_document:
        print("job_info_id missing.")
        exit(1)
 
    es_document['id'] = es_document['job_info_id']
 
 
    
    if 'job_info_created' in es_document:
        value = es_document['job_info_created']
        if value:
            if len(value) >= 11:
                if value[10] == " ":
                    es_document['job_info_created']=value[:10]+"T"+value[11:]
    
    pprint(es_document)
    
   
        
    #exit(1)
    return es_document
    


######################### main ##########################


properties = get_schema_properties()


print("***************** properties:\n")
pprint(properties)









result = api.get("/metagenome", params={"verbosity": "minimal"})

result_obj = result.json()

total_count = result_obj["total_count"]


success = 0
failure = 0
count = 0
for elem in api.get_stream("/metagenome", params={"verbosity": "minimal"}):
    count +=1
    pprint(elem)
    print("------------------------------------------------------\n") 
    transfer_id = elem["id"]
    print(transfer_id+"\n")
    r = None
    
    
   
    
    try:
        r= transfer_document(transfer_id)
    except Exception as e:
        print("Exception transfer_document: %s" % (str(e)))
        
    
    
    if r:
        success +=1
    else:
        failure += 1
        print("ERROR\n")
        exit(1)
        
    print("%d / %d  (success: %d  , failure: %d)" % (count, total_count, success, failure))
    

    #PUT /{index}/{type}/{id}