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
    result = api.get("metagenome/"+id, params={"verbosity": "full"})
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
    
    return result_obj

#load document into ES
def load_document(_id, data_dict):
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

def fix_document(data):
    
    # deprecated
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

    #fix_document(data)

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



def get_schema_properties():


    schema=None
    with open('metagenome_schema.json') as json_data:
        schema = json.load(json_data)
        pprint(schema)
    
    
        
    properties = schema["mappings"]["metagenome_metadata"]["properties"]
    return properties



def create_es_doc_from_api_doc(api_data):
    es_document = {}


    for key in ['name', 'pipeline_version', 'status', 'version']:
        es_document[key] = api_data[key]
        del api_data[key]

    es_document['id'] = api_data['job_id']
    es_document['job'] = api_data['job_id']
    del api_data['job_id']

    es_document['created']=api_data['created']
    del api_data['created']

    # project
    delete_keys=[]
    project_data = api_data['metadata']['project']['data']
    project_all=""
    for key, value in project_data.items():
        project_all += str(value) + " "
        if not key in properties:
            print("WARNING: %s not in schema" % (key))
            continue
        es_document[key] = value
        delete_keys.append(key)

    for key in delete_keys:
        del project_data[key]


    try:
        es_document['project_all'] = project_all
    except KeyError:
        pass


    # sample
    delete_keys=[]
    sample_data = api_data['metadata']['sample']['data']
    sample_all = ""
    for key, value in sample_data.items():
        sample_all += str(value) + " "
        if not key in properties:
            print("WARNING: %s not in schema" % (key))
            continue
        es_document[key] = value
        delete_keys.append(key)

    for key in delete_keys:
        del sample_data[key]



    try:
        es_document['sample_all'] = sample_all
    except KeyError:
        pass

    try:
        es_document['sample_id']=api_data['metadata']['sample']['id']
        del api_data['metadata']['sample']['id']
    except KeyError:
        pass

    try:
        es_document['sample_name']=api_data['metadata']['sample']['name']
        del api_data['metadata']['sample']['name']
    except KeyError:
        pass


    # library
    delete_keys=[]
    library_data = api_data['metadata']['library']['data']
    library_all=''
    for key, value in library_data.items() :
        library_all += str(value) + " "
        if not key in properties:
            print("WARNING: %s not in schema" % (key))
            continue
        es_document[key] = value
        delete_keys.append(key)

    for key in delete_keys:
        del library_data[key]

    try:
        es_document['library_all'] = library_all
    except KeyError:
        pass

    try:
        es_document['library_id']=api_data['metadata']['library']['id']
        del api_data['metadata']['library']['id']
    except KeyError:
        pass

    try:
        es_document['library_name']=api_data['metadata']['library']['name']
        del api_data['metadata']['library']['name']
    except KeyError:
        pass


    # mixs
    delete_keys=[]
    mixs_data = api_data['mixs']
    for key, value in mixs_data.items():
        if not key in properties:
            print("WARNING: %s not in schema" % (key))
            continue
        es_document[key] = value
        delete_keys.append(key)
    
    for key in delete_keys:
        del mixs_data[key]


    #pipeline_parameters
    delete_keys=[]
    pipeline_parameters = api_data['pipeline_parameters']
    for key, value in pipeline_parameters.items():
        if not key in properties:
            print("WARNING: %s not in schema" % (key))
            continue
        es_document[key] = value
        delete_keys.append(key)
    
    for key in delete_keys:
        del pipeline_parameters[key]

    # env_package_data
    delete_keys=[]
    env_package_data = api_data['metadata']['env_package']['data']
    env_package_all = ""
    for key, value in env_package_data.items():
        env_package_all += str(value) + " "
        if not key in properties:
            print("WARNING: %s not in schema" % (key))
            continue
        es_document[key] = value
        delete_keys.append(key)
    
    for key in delete_keys:
        del env_package_data[key]




    try:
        es_document['env_package_id']=api_data['metadata']['env_package']['id']
        del api_data['metadata']['env_package']['id']
    except KeyError:
        pass

    try:
        es_document['env_package_name']=api_data['metadata']['env_package']['name']
        del api_data['metadata']['env_package']['name']
    except KeyError:
        pass


    es_document['env_package_all'] = env_package_all
    del api_data['metadata']['env_package']


    sequence_stats =  api_data['statistics']['sequence_stats']
    for key, value in sequence_stats.items():
        value_type = type(value)
        if value_type is float:
            es_document[key+'_d']=value
        elif value_type is int:
            es_document[key+'_l']=value
        else:
            print("type %s not supoorted" % (str(value_type)))
            exit(1)
        

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
    print(elem)
    r = None
    api_data = None
    try:
        #r = transfer_document(elem["id"])
        transfer_id = elem["id"]
        if es_find_document(transfer_id):
            print("%s already found, skipping..." % (transfer_id))
            continue
        else:
            print("Getting %s from API..." % (transfer_id))
    except Exception as e:
         print("Exception es_find_document: %s" % (str(e)))
         r = None
         
    try:
        api_data = read_metadata_from_api(transfer_id)

        print("***************** metadata from API:\n")
        pprint(api_data)

    except Exception as e:
        print("Exception read_metadata_from_api: %s" % (str(e)))
        r = None
    es_document = None
    try:
            
        es_document = create_es_doc_from_api_doc(api_data)
    except Exception as e:
        print("Exception create_es_doc_from_api_doc: %s" % (str(e)))
        r = None

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
        r = None
        
    try:

        print("***************** api_data after using data:\n")
        pprint(api_data)
        
    except Exception as e:
        print("Exception transferring document B: %s" % (str(e)))
        r = None
    
    if r:
        success +=1
    else:
        failure += 1
        print("ERROR\n")
        
    print("%d / %d  (success: %d  , failure: %d)" % (count, total_count, success, failure))
    

    #PUT /{index}/{type}/{id}