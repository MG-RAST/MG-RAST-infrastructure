
######### M5NR #########

1. export from postgres - IF updating m5nr version 

  - use api/mgrast container
  - run: https://github.com/MG-RAST/MG-RAST/blob/develop/src/MGRAST/bin/export_annotation_for_cass.pl
  - upload to shock:
    - tar -zcvf m5nr_v{version #}.cass.tgz m5nr_v{version #}.*
    - curl -X POST -F 'attributes_str={"created": "{DATE}", "data_type": "m5nr annotation", "description": "gzip tar of m5nr annotations in cassandra load format version {version #}", "file_format": "tgz", "name": "cassandra", "type": "reference", "version": "{version #}"}' -F 'upload=@m5nr_v{version #}.cass.tgz' http://shock.metagenomics.anl.gov/node
  - edit load script to add new shock node

2. load into cassandra

  - use cassandra container
    - update: apt-get update && apt-get install -y curl vim openjdk-8-jdk
  - run: https://github.com/MG-RAST/MG-RAST-infrastructure/blob/master/services/cassandra-load/m5nr/load-cassandra-m5nr.sh
  - creates keyspace: m5nr_v{version #}

######### MD5 Abundances #########

1. export from postgres

  - use api/mgrast container
  - run: https://github.com/MG-RAST/MG-RAST/blob/develop/src/MGRAST/bin/export_jobmd5s_for_cass.pl
    - will get three files per metagenome job ID (one for each table)
    - these files can be concatenated by table - end up with three files for all jobs

2. load into cassandra

  - use cassandra container
    - update: apt-get update && apt-get install -y curl vim openjdk-8-jdk
    - mount dir with job data into container
  - set schema if first time (skip this if keyspace exists):
    - curl -O https://raw.githubusercontent.com/MG-RAST/MG-RAST-infrastructure/master/services/cassandra-load/mgrast_analysis/job_table.cql
    - /usr/bin/cqlsh -f job_table.cql
  - run: https://github.com/MG-RAST/MG-RAST-infrastructure/blob/master/services/cassandra-load/mgrast_analysis/load-cassandra-analysis.sh
  - IP_LIST=`fleetctl list-units | grep cassandra | cut -f2 -d"/" | cut -f1 | sort -u | tr "\n" "," | sed s/.$//`
  - example: load-cassandra-analysis.sh -a $IP_LIST -d \<dir with job_id.table files\> -k mgrast_analysis
  
### Check data

docker exec cassandra /usr/bin/nodetool status {keyspace}
