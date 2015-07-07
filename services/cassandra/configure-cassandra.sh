#!/bin/bash

CONF_DIR=""
BASE_DIR=""
DATA_DIR=""
PUBLIC_IP=""
CNAME="MG-RAST Cluster"

while getopts c:b:d:i: option; do
    case "${option}"
        in
            c) CONF_DIR=${OPTARG};;
            b) BASE_DIR=${OPTARG};;
            d) DATA_DIR=${OPTARG};;
            i) PUBLIC_IP=${OPTARG};;
    esac
done

cd $BASE_DIR/agent/conf
curl -s -O https://raw.githubusercontent.com/MG-RAST/MG-RAST-infrastructure/master/services/opscenter/address.yaml

cd $BASE_DIR/cassandra/conf
sed -e "s;\[\% public_ip \%\];$PUBLIC_IP;g" -e "s;\[\% data_dir \%\];$DATA_DIR;g" -e "s;\[\% clust_name \%\];$CNAME;g" $CONF_DIR/cassandra.yaml > cassandra.yaml
