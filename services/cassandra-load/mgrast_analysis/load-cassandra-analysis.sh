#!/bin/bash

set -e

# set default value
ALL_IPS=""
DATA_DIR=""
KEYSPACE=""
BASE_DIR="/var/lib/cassandra"
CASS_BIN="/usr/bin"
CASS_DIR="/usr/share/cassandra"
CASS_CONF="/etc/cassandra/cassandra.yaml"

while getopts a:d:k: option; do
    case "${option}"
        in
            a) ALL_IPS=${OPTARG};;
            d) DATA_DIR=${OPTARG};;
            k) KEYSPACE=${OPTARG};;
    esac
done

if [ -z "$DATA_DIR" ]; then
    DATA_DIR=$BASE_DIR/data/bulkload
fi

if [ -z "$ALL_IPS" ]; then
    echo "Missing IPs"
    exit 1
fi

set -x

LOAD_DIR=$BASE_DIR/BulkLoader
SST_DIR=$BASE_DIR/sstable
CQLSH=$CASS_BIN/cqlsh
SST_LOAD=$CASS_BIN/sstableloader

mkdir -p $LOAD_DIR
mkdir -p $SST_DIR

# download bulkloader
cd $LOAD_DIR
if [ ! -f BulkLoader.sh ] ; then
    curl -s -O https://raw.githubusercontent.com/MG-RAST/MG-RAST-infrastructure/master/services/cassandra-load/BulkLoader/BulkLoader.sh
    curl -s -O https://raw.githubusercontent.com/MG-RAST/MG-RAST-infrastructure/master/services/cassandra-load/BulkLoader/BulkLoader.java
    curl -s -O https://raw.githubusercontent.com/MG-RAST/MG-RAST-infrastructure/master/services/cassandra-load/BulkLoader/opencsv-3.4.jar
fi

for TABLE in job_info job_md5s job_lcas; do
    echo "Creating $TABLE sstables ..."
    for FILE in `ls $DATA_DIR/*.${TABLE}`; do
        split -a 2 -d -l 2000000 ${FILE} ${FILE}.
        for PART in `ls ${FILE}.*`; do
            /bin/bash BulkLoader.sh -c $CASS_CONF -d $CASS_DIR -k $KEYSPACE -t $TABLE -i $PART -o $SST_DIR
            rm -v $PART
        done
    done
    echo "Loading $TABLE sstables ..."
    $SST_LOAD -f $CASS_CONF -d $ALL_IPS $SST_DIR/$KEYSPACE/$TABLE
done

exit 0
