#!/usr/bin/env python

import sys
import json
from optparse import OptionParser
from mglib import *

usage = "usage: %prog [options] --token <mgrast auth token> --mgid <metagenome id to delete>"
version = "%prog 1.0"

def main(args):
    global API_URL
    parser = OptionParser(usage=usage, version=version)
    parser.add_option("-u", "--mgrast_url", dest="mgrast_url", default=API_URL, help="MG-RAST API url")
    parser.add_option("-r", "--reason", dest="reason", default=None, help="Reason for deletion of metagenome")
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
    
    user_info = get_login(opts.token)
    reason = "Deleted by user %s (%s)"%(user_info['login'], user_info['id'])
    if opts.reason:
        reason += ": "+opts.reason
    
    delete_mg = obj_from_url(API_URL+"/job/delete", data=json.dumps({'metagenome_id': opts.mgid, 'reason': reason}), token=opts.token)
    if delete_mg['deleted'] == 1:
        print "sucessfully deleted "+opts.mgid
        return 0
    else:
        sys.stderr.write("ERROR: unable to delete %s: %s"%(opts.mgid, delete_mg['error']))
        return 1

if __name__ == "__main__":
    sys.exit( main(sys.argv) )
