
#!/bin/bash


if [[ $_ == $0 ]]; then
  echo "Error: please use command \"source ./init.sh\""
  exit 1
fi

set -x

export SERVICE_DIR="/media/ephemeral/mms/"

export MMS_CONFIG_FILE=${SERVICE_DIR}/mgrast-config/services/mms/config.yml
export RABBITMQ_DEFAULT_USER=$(grep -A 2 "^rabbitmq:" ${MMS_CONFIG_FILE} | grep " user:" | awk '{print$2}')
export RABBITMQ_DEFAULT_PASS=$(grep -A 2 "^rabbitmq:" ${MMS_CONFIG_FILE} | grep " password:" | awk '{print$2}')
export MYSQL_ROOT_PASSWORD=$(grep -A 6 "^mysql:" ${MMS_CONFIG_FILE} | grep " root_password:" | awk '{print$2}')
export MYSQL_USER=$(grep -A 6 "^mysql:" ${MMS_CONFIG_FILE} | grep " user:" | awk '{print$2}')
export MYSQL_PASSWORD=$(grep -A 6 "^mysql:" ${MMS_CONFIG_FILE} | grep " root_password:" | awk '{print$2}')


