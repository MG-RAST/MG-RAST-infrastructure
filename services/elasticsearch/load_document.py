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
    
    
    for key in properties:
        if key in es_document:
            expected_type = properties[key]['type']
            
            
            this_type = type(es_document[key])
            
            if this_type == int:
                this_type_str="integer"
            elif this_type == str:
                this_type_str="string"
            else:
                print(str(this_type))
                exit(1)
            
            
                
            if expected_type=="integer" and this_type_str=="string":
                es_document[key]=int(es_document[key])
                continue
                
            if expected_type=="boolean" and this_type_str=="string":
                if es_document[key] == "yes":
                    es_document[key]=True
                elif es_document[key] == "no":
                    es_document[key]=False
                else:
                    print(str(this_type))
                    exit(1)
                continue
                    
            if expected_type=="float" and this_type_str=="string":
                es_document[key]=float(es_document[key])
                continue
            
            if expected_type=="date" and this_type_str=="string":
                continue
                
            if this_type_str != expected_type:
                print("key: %s %s %s\n", key, expected_type, this_type_str )
                print("%s %s\n", key, es_document[key])
                exit(1)
    
    for date in ['created']:
        if date in es_document:
            #del es_document[date]
            #continue # TODO fix API !!!
            value = es_document[date]
            if value:
                if len(value) >= 11:
                    if value[10] == " ":
                        es_document[date]=value[:10]+"T"+value[11:]
    
    print("sending...")
    pprint(es_document)
    loading_ok = False
    try:
        loading_ok = load_document(es_document)
    except Exception as e:
      print("Exception transferring document B: %s" % (str(e)))
      return False
    
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


    if api_data == None:
        sys.exit(1)

    for key in ['name', 'pipeline_version', 'status', 'version']:
        es_document[key] = api_data[key]
        del api_data[key]

    es_document['id'] = api_data['job_id']
    es_document['job'] = api_data['job_id']
    del api_data['job_id']

    es_document['created']=api_data['created']
    del api_data['created']

    
    # project
    print("project")
    delete_keys=[]
    project_data = None
    try:
        project_data = api_data['metadata']['project']['data']
    except Exception:
        print("no project data found")
        pass
        
    if project_data: 
        project_all=""
        for key, value in project_data.items():
            if value:
                print(key)
                project_all += str(value) + " "
                if not key in properties:
                    print("WARNING: %s not in schema" % (key))
                    continue
                es_document[key] = value
                delete_keys.append(key)
    
        print("delete")
        for key in delete_keys:
            del project_data[key]


        try:
            es_document['project_all'] = project_all
        except KeyError:
            pass


    # sample
    print("sample")
    delete_keys=[]
    sample_data = None
    try:
        sample_data = api_data['metadata']['sample']['data']
    except Exception:
        print("no sample data found")
        pass
    
    if sample_data: 
        sample_all = ""
        for key, value in sample_data.items():
            if value:
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
    print("library")
    delete_keys=[]
    library_data = None
    try:
        library_data = api_data['metadata']['library']['data']
    except Exception:
        print("no library data found")
        pass
    
    if library_data:
        library_all=''
        for key, value in library_data.items():
            if value:
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
    print("mixs")
    delete_keys=[]
    mixs_data = None
    try:
        mixs_data = api_data['mixs']
    except Exception:
        print("no mixs data found")
        pass
    
    if mixs_data:
        for key, value in mixs_data.items():
            if key != 'collection_date':
                if not key in properties:
                    print("WARNING: %s not in schema" % (key))
                    continue
                if value:
                    es_document[key] = value
                    delete_keys.append(key)
    
        for key in delete_keys:
            del mixs_data[key]


    #pipeline_parameters
    print("pipeline_parameters")
    delete_keys=[]
    pipeline_parameters = api_data['pipeline_parameters']
    for key, value in pipeline_parameters.items():
        if value:
            if not key in properties:
                print("WARNING: %s not in schema" % (key))
                continue
            es_document[key] = value
            delete_keys.append(key)
    
    for key in delete_keys:
        del pipeline_parameters[key]

    # env_package_data
    print("env_package_data")
    delete_keys=[]
    env_package_data = None
    try:
        env_package_data = api_data['metadata']['env_package']['data']
    except Exception:
        print("no env_package data found")
        pass
    
    if env_package_data:
        env_package_all = ""
        for key, value in env_package_data.items():
            if value:
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

    print("sequence_stats")
    sequence_stats =  api_data['statistics']['sequence_stats']
    for key, value in sequence_stats.items():
        if value:
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
        exit(1)
        print("ERROR\n")
        
    print("%d / %d  (success: %d  , failure: %d)" % (count, total_count, success, failure))
    

    #PUT /{index}/{type}/{id}