#!/bin/bash

set -e

# set default value
ALL_IPS=""
DATA_DIR=""
KEYSPACE=""
TABLE=""
PORT=""
BASE_DIR="/var/lib/cassandra"
CASS_BIN="/usr/bin"
CASS_DIR="/usr/share/cassandra"
CASS_CONF="/etc/cassandra/cassandra.yaml"

while getopts a:d:k:t:p: option; do
    case "${option}"
        in
            a) ALL_IPS=${OPTARG};;
            d) DATA_DIR=${OPTARG};;
            k) KEYSPACE=${OPTARG};;
            t) TABLE=${OPTARG};;
            p) PORT=${OPTARG};;
    esac
done

if [ -z "$DATA_DIR" ]; then
    DATA_DIR=$BASE_DIR/data/bulkload
fi

if [ -z "$ALL_IPS" ]; then
    echo "Missing IPs"
    exit 1
fi

if [ -z "$PORT" ]; then
    PORT=9042
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
curl -s -O https://raw.githubusercontent.com/MG-RAST/MG-RAST-infrastructure/master/services/cassandra-load/BulkLoader/BulkLoader.sh
curl -s -O https://raw.githubusercontent.com/MG-RAST/MG-RAST-infrastructure/master/services/cassandra-load/BulkLoader/BulkLoader.java
curl -s -O https://raw.githubusercontent.com/MG-RAST/MG-RAST-infrastructure/master/services/cassandra-load/BulkLoader/opencsv-3.4.jar

# split large files
echo "Splitting input files ..."
cd $DATA_DIR
for FILE in *.${TABLE}; do
    split -a 2 -d -l 2000000 ${FILE} ${FILE}.
done

# create sstables
echo "Creating sstables ..."
cd $LOAD_DIR
for FILE in `ls $DATA_DIR/*.${TABLE}.*`; do
    /bin/bash BulkLoader.sh -c $CASS_CONF -d $CASS_DIR -k $KEYSPACE -t $TABLE -i $FILE -o $SST_DIR
    rm -v $FILE
done

# load sstable
echo "Loading sstables ..."
$SST_LOAD -p $PORT -d $ALL_IPS $SST_DIR/$KEYSPACE/$TABLE

exit 0