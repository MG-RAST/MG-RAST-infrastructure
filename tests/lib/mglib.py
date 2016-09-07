import os
import sys
import time
import urllib2
import urlparse
import json
import string
import random

API_URL = "http://api.metagenomics.anl.gov"
BEARER  = 'mgrast'

# return python struct from JSON output of MG-RAST API
def obj_from_url(url, token=None, data=None, debug=False, method=None):
    header = {'Accept': 'application/json'}
    if token:
        header['Authorization'] = BEARER+' '+token
    if data or method:
        header['Content-Type'] = 'application/json'
    if debug:
        if data:
            print "data:\t"+data
        print "header:\t"+json.dumps(header)
        print "url:\t"+url
    try:
        req = urllib2.Request(url, data, headers=header)
        if method:
            req.get_method = lambda: method
        res = urllib2.urlopen(req)
    except urllib2.HTTPError, error:
        if debug:
            sys.stderr.write("URL: %s\n" %url)
        try:
            eobj = json.loads(error.read())
            sys.stderr.write("ERROR (%s): %s\n" %(error.code, eobj['ERROR']))
        except:
            sys.stderr.write("ERROR (%s): %s\n" %(error.code, error.read()))
        finally:
            sys.exit(1)
    if not res:
        if debug:
            sys.stderr.write("URL: %s\n" %url)
        sys.stderr.write("ERROR: no results returned\n")
        sys.exit(1)
    obj = json.loads(res.read())
    if obj is None:
        if debug:
            sys.stderr.write("URL: %s\n" %url)
        sys.stderr.write("ERROR: return structure not valid json format\n")
        sys.exit(1)
    if len(obj.keys()) == 0:
        if debug:
            sys.stderr.write("URL: %s\n" %url)
        sys.stderr.write("ERROR: no data available\n")
        sys.exit(1)
    if 'ERROR' in obj:
        if debug:
            sys.stderr.write("URL: %s\n" %url)
        sys.stderr.write("ERROR: %s\n" %obj['ERROR'])
        sys.exit(1)
    return obj

# return python struct from JSON output of asynchronous MG-RAST API
def async_rest_api(url, token=None, data=None, debug=False, delay=15):
    parameters = urlparse.parse_qs(url.split("?")[1])
    assert "asynchronous" in parameters, "Must specify asynchronous=1 for asynchronous call!"
    submit = obj_from_url(url, token=token, data=data, debug=debug)
    if not (('status' in submit) and (submit['status'] == 'submitted') and ('url' in submit)):
        sys.stderr.write("ERROR: return data invalid format\n:%s"%json.dumps(submit))
    result = obj_from_url(submit['url'], debug=debug)
    while result['status'] != 'done':
        if debug:
            print "waiting %d seconds ..."%delay
        time.sleep(delay)
        result = obj_from_url(submit['url'], debug=debug)
    if 'ERROR' in result['data']:
        if debug:
            sys.stderr.write("URL: %s\n" %url)
        sys.stderr.write("ERROR: %s\n" %result['data']['ERROR'])
        sys.exit(1)
    return result['data']

def random_str(size=10):
    chars = string.ascii_letters + string.digits
    return ''.join(random.choice(chars) for x in range(size))

def get_login(token):
    return obj_from_url(API_URL+"/user/authenticate", token=token)
