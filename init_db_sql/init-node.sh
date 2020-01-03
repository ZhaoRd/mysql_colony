#!/bin/bash

# check mysql master run status

set -e

echo "mysql node init"

until MYSQL_PWD=${MASTER_MYSQL_ROOT_PASSWORD} mysql -u root -h ${MASTER_HOST} ; do
  >&2 echo "MySQL master is unavailable - sleeping"
  sleep 5
done

echo "connect mysql master success"

# create replication user

mysql_net=$(hostname -i | sed "s/\.[0-9]\+$/.%/g")

MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root \
-e "CREATE USER '${MYSQL_REPLICATION_USER}'@'${mysql_net}' IDENTIFIED BY '${MYSQL_REPLICATION_PASSWORD}'; \
GRANT REPLICATION SLAVE ON *.* TO '${MYSQL_REPLICATION_USER}'@'${mysql_net}';\
"

# get master log File & Position

master_status_info=$(MYSQL_PWD=${MASTER_MYSQL_ROOT_PASSWORD} mysql -u root -h ${MASTER_HOST} -e "show master status\G")
echo "master_status_info -----------------------------"
echo ${master_status_info}

LOG_FILE=$(echo "${master_status_info}" | awk 'NR!=1 && $1=="File:" {print $2}')
LOG_POS=$(echo "${master_status_info}" | awk 'NR!=1 && $1=="Position:" {print $2}')

echo "LOG_FILE -----------------------------"
echo ${LOG_FILE}

echo "LOG_POS -----------------------------"
echo ${LOG_POS}


# set node master

echo "MASTER_HOST -----------------------------"
echo ${MASTER_HOST}

MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root \
-e "CHANGE MASTER TO MASTER_HOST='${MASTER_HOST}', \
MASTER_USER='${MYSQL_REPLICATION_USER}', \
MASTER_PASSWORD='${MYSQL_REPLICATION_PASSWORD}', \
MASTER_LOG_FILE='${LOG_FILE}', \
MASTER_LOG_POS=${LOG_POS};"

# 用户密码加密方式导致的语句错误
#, \
#GET_MASTER_PUBLIC_KEY=1

# start slave and show slave status

MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root -e "START SLAVE;show slave status\G"

echo "myssql node init  end"