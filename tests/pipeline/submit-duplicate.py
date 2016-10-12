#!/usr/bin/env python

import sys
import json
from optparse import OptionParser
from mglib import *

usage = "usage: %prog [options] --token <mgrast auth token> --mgid <metagenome id to duplicate>"
version = "%prog 1.0" 

def main(args):
    global API_URL
    parser = OptionParser(usage=usage, version=version)
    parser.add_option("-u", "--mgrast_url", dest="mgrast_url", default=API_URL, help="MG-RAST API url")
    parser.add_option("-t", "--token", dest="token", default=None, help="MG-RAST token")
    parser.add_option("-m", "--mgid", dest="mgid", default=None, help="MG-RAST ID")
    
    # get inputs
    (opts, args) = parser.parse_args()
    API_URL = opts.mgrast_url
    if not opts.token:
        sys.stderr.write("ERROR: missing token\n")
        return 1
    if not opts.mgid:
        sys.stderr.write("ERROR: missing mgid\n")
        return 1
    
    # get parent metagenome info
    mgdata = obj_from_url(API_URL+"/metagenome/"+opts.mgid, token=opts.token)
    if ('pipeline_parameters' not in mgdata) or (mgdata['pipeline_parameters'] is None) or (len(mgdata['pipeline_parameters']) == 0):
        sys.stderr.write("ERROR: missing pipeline parameters for "+opts.mgid+"\n")
        return 1    
    upload = obj_from_url(API_URL+"/download/"+opts.mgid+"?stage=upload", token=opts.token)
    if ('data' not in upload) or (upload['data'] is None) or (len(upload['data']) == 0):
        sys.stderr.write("ERROR: missing upload sequence file for "+opts.mgid+"\n")
        return 1
    input_node  = upload['data'][0]['node_id']
    input_stats = upload['data'][0]['statistics']
    
    # reserve new metagenome ID
    reserve_job = obj_from_url(API_URL+"/job/reserve", data=json.dumps({'name': mgdata['name'], 'input_id': input_node}), token=opts.token)
    new_mgid = reserve_job['metagenome_id']
    # create duplicate metagenome
    create_data = mgdata['pipeline_parameters'].copy()
    create_data.update(input_stats)
    create_data.update({
        'sequencing_method_guess': mgdata['sequence_type'],
        'sequence_type': mgdata['sequence_type'],
        'metagenome_id': new_mgid,
        'input_id': input_node
    })
    create_job = obj_from_url(API_URL+"/job/create", data=json.dumps(create_data), token=opts.token)
    print "metagenome id:\t%s"%new_mgid
    print "internal job id:\t%d"%reserve_job['job_id']
    print "job option str:\t%s"%create_job['options']

    # submit it
    submit_job = obj_from_url(API_URL+"/job/submit", data=json.dumps({'metagenome_id': new_mgid, 'input_id': input_node}), token=opts.token)
    print "awe job id:\t%s"%submit_job['awe_id']
    
    return 0

if __name__ == "__main__":
    sys.exit( main(sys.argv) )
