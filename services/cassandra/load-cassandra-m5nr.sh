#!/bin/bash

# set default value
MY_IP=""
ALL_IPS=""
VERSION=""
REP_NUM=""
DATA_DIR=""
SCHEMA_DIR="/schema"
CASS_DIR="/opt/cassandra"

while getopts i:a:v:r:d: option; do
    case "${option}"
        in
            i) MY_IP=${OPTARG};;
            a) ALL_IPS=${OPTARG};;
            v) VERSION=${OPTARG};;
            r) REP_NUM=${OPTARG};;
            o) DATA_DIR=${OPTARG};;
    esac
done

if [ -z "$VERSION" ]; then
    VERSION="1"
fi
if [ -z "$REP_NUM" ]; then
    REP_NUM="3"
fi
if [ -z "$DATA_DIR" ]; then
    DATA_DIR="/data"
fi

LOAD_DIR=$DATA_DIR/BulkLoader
M5NR_DATA=$SRC_DIR/src/v${VERSION}
SCHEMA_TABLE=$SCHEMA_DIR/m5nr_table_v${VERSION}.cql
SCHEMA_COPY=$SCHEMA_DIR/m5nr_copy_v${VERSION}.cql

CQLSH=$CASS_DIR/bin/cqlsh
SST_LOAD=$CASS_DIR/bin/sstableloader

# download schema template
mkdir -p $SCHEMA_DIR
cd $SCHEMA_DIR
curl -s https://raw.githubusercontent.com/MG-RAST/MG-RAST/develop/src/MGRAST/Schema/m5nr_table.cql.tt | \
    sed -e "s;[% version %];$VERSION;g" -e "s;[% replication %];$REP_NUM;g" > $SCHEMA_TABLE
curl -s https://raw.githubusercontent.com/MG-RAST/MG-RAST/develop/src/MGRAST/Schema/m5nr_copy.cql.tt | \
    sed -e "s;[% version %];$VERSION;g" -e "s;[% data_dir %];$M5NR_DATA;g" > $SCHEMA_COPY

# download bulkloader
mkdir -p $LOAD_DIR
cd $LOAD_DIR
curl -s -O https://raw.githubusercontent.com/MG-RAST/MG-RAST/develop/src/MGRAST/tools/BulkLoader/BulkLoader.sh > BulkLoader.sh
curl -s -O https://raw.githubusercontent.com/MG-RAST/MG-RAST/develop/src/MGRAST/tools/BulkLoader/BulkLoader.java > BulkLoader.java
curl -s -O https://raw.githubusercontent.com/MG-RAST/MG-RAST/develop/src/MGRAST/tools/BulkLoader/opencsv-3.4.jar > opencsv-3.4.jar

# download data
DATA_URL=""
if [ "$VERSION" == "1" ]; then
    DATA_URL="http://shock.metagenomics.anl.gov/node/?download"
elif [ "$VERSION" == "10" ]; then
    DATA_URL="http://shock.metagenomics.anl.gov/node/foo?download"
fi
if [ "$DATA_URL" == "" ]; then
    echo "Data files not found for this m5nr version."
    exit 1
fi

echo ""
echo "REPLICATES = $REP_NUM"
echo "M5NR_VERSION = $VERSION"
echo "M5NR_DATA = $M5NR_DATA"
echo "DATA_URL = $DATA_URL"
echo ""

if [ ! -d $M5NR_DATA ]; then
    mkdir -p $M5NR_DATA
    echo "Downloading and unpacking data ..."
    curl -s "${DATA_URL}" | tar -zxvf - -C $M5NR_DATA
fi

# load tables
echo "Loading schema ..."
$CQLSH -f $SCHEMA_TABLE $MY_IP

echo "Copying small data ..."
sed -i "s;\(^import csv$\);\1\ncsv.field_size_limit(1000000000);" $CQLSH
$CQLSH -f $SCHEMA_COPY $MY_IP

echo "Creating / loading sstables ..."
SST_DIR=$DATA_DIR/sstable
KEYSPACE=m5nr_v${VERSION}
mkdir -p $SST_DIR
for TYPE in id md5; do
    # split large file
    cd $M5NR_DATA
    split -a 2 -d -l 2500000 ${KEYSPACE}.annotation.${TYPE} ${KEYSPACE}.annotation.${TYPE}.
    # create sstables
    cd $LOAD_DIR
    for FILE in `ls $M5NR_DATA/${KEYSPACE}.annotation.${TYPE}.*`; do
        /bin/bash BulkLoader.sh -c -k $KEYSPACE -t ${TYPE}_annotation -i $FILE -o $SST_DIR
    done
    # load sstable
    $SST_LOAD -d $ALL_IPS $SST_DIR/$KEYSPACE/${TYPE}_annotation
done

exit 0