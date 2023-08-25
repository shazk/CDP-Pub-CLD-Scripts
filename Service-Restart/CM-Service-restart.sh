#!/usr/bin/env bash
#
# Description: Script to restart Cluster Services using the CM API.
#              This script needs to run from the CM node as the root user.
#              Requires a Workload user and password.
# Changes:
# Date       Author               Description
# ---------- ------------------- ---------------------------------------------------------
# 10/30/2021 Jimmy Garagorry.     Created
# 03/04/2022 Jimmy Garagorry.     Updated input method for user credentials
# 03/06/2022 Jimmy Garagorry.     Added Color Schemas
#==========================================================================================
# Black        0;30     Dark Gray     1;30
# Red          0;31     Light Red     1;31
# Green        0;32     Light Green   1;32
# Brown/Orange 0;33     Yellow        1;33
# Blue         0;34     Light Blue    1;34
# Purple       0;35     Light Purple  1;35
# Cyan         0;36     Light Cyan    1;36
# Light Gray   0;37     White         1;37

RED='\033[0;31m'
NC='\033[0m' # No Color

clear
read -p "What is your Workload username: "  WORKLOAD_USER

unset WORKLOAD_USER_PASS
unset CHARTCOUNT

echo -n "Enter your Workload user Password: "
#stty -echo

while IFS= read -r -n1 -s CHAR; do
    case "${CHAR}" in
    $'\0')
        break
        ;;
    $'\177')
        if [ ${#WORKLOAD_USER_PASS} -gt 0 ]; then
            echo -ne "\b \b"
            WORKLOAD_USER_PASS=${WORKLOAD_USER_PASS::-1}
        fi
        ;;
    *)
        CHARTCOUNT=$((CHARTCOUNT + 1))
        echo -n '*'
        WORKLOAD_USER_PASS+="${CHAR}"
        ;;
    esac
done
echo

export CM_SERVER_DB_FILE=/etc/cloudera-scm-server/db.properties
export CM_DB_HOST=$(awk -F"=" '/db.host/ {print $NF}' ${CM_SERVER_DB_FILE})
export CM_DB_NAME=$(awk -F"=" '/db.name/ {print $NF}' ${CM_SERVER_DB_FILE})
export CM_DB_USER=$(awk -F"=" '/db.user/ {print $NF}' ${CM_SERVER_DB_FILE})
export PGPASSWORD=$(awk -F"=" '/db.password/ {print $NF}' ${CM_SERVER_DB_FILE})
export CM_CLUSTER_NAME=$(echo -e "SELECT name FROM clusters;" | psql -h ${CM_DB_HOST} -U ${CM_DB_USER} -d ${CM_DB_NAME} | grep -v Proxy | tail -n 3 | head -n1| sed 's| ||g')
export CM_SERVER="https://$(hostname -f):7183"

function do_test_credentials () {
  curl -s -L -k -u ${WORKLOAD_USER}:${WORKLOAD_USER_PASS} -X GET "${CM_SERVER}/api/version" > /tmp/null 2>&1
  if grep "Bad credentials" /tmp/null > /dev/null 2>&1
  then
    CRED_VALIDATED=1
    echo -e "\n===> ${RED}Please double-check the credentials provided${NC} <===\n"
    rm -rf /tmp/null 
  else
    CRED_VALIDATED=0
    rm -rf /tmp/null 
  fi
}

do_test_credentials

if [[ ${CRED_VALIDATED} == 0 ]]
then
 export CM_API_VERSION=$(curl -s -L -k -u ${WORKLOAD_USER}:${WORKLOAD_USER_PASS} -X GET "${CM_SERVER}/api/version")
else
 exit 1
fi

function cluster_service_status () {
curl -s -L -k -u ${WORKLOAD_USER}:${WORKLOAD_USER_PASS} -X GET "${CM_SERVER}/api/${CM_API_VERSION}/clusters/${CM_CLUSTER_NAME}/services/${CLUSTER_SERIVCE_NAME}"
}

function cluster_service_stop () {
curl -s -L -k -u ${WORKLOAD_USER}:${WORKLOAD_USER_PASS} -X POST "${CM_SERVER}/api/${CM_API_VERSION}/clusters/${CM_CLUSTER_NAME}/services/${CLUSTER_SERIVCE_NAME}/commands/stop"
}

function cluster_service_start () {
curl -s -L -k -u ${WORKLOAD_USER}:${WORKLOAD_USER_PASS} -X POST "${CM_SERVER}/api/${CM_API_VERSION}/clusters/${CM_CLUSTER_NAME}/services/${CLUSTER_SERIVCE_NAME}/commands/start"
}

function cluster_service_restart () {
curl -s -L -k -u ${WORKLOAD_USER}:${WORKLOAD_USER_PASS} -X POST "${CM_SERVER}/api/${CM_API_VERSION}/clusters/${CM_CLUSTER_NAME}/services/${CLUSTER_SERIVCE_NAME}/commands/restart"
}

for CLUSTER_SERIVCE_NAME in $(curl -s -L -k -u ${WORKLOAD_USER}:${WORKLOAD_USER_PASS} -X GET "${CM_SERVER}/api/${CM_API_VERSION}/clusters/${CM_CLUSTER_NAME}/services"|jq -r '.items[].name')
do
  PS3="What do you want to do for << ${CLUSTER_SERIVCE_NAME^^} >> Service? [-> For Menu Press Enter <-]: "
  echo -e "\n=== CLUSTER: ${RED}${CM_CLUSTER_NAME}${NC} | SERVICE: ${RED}${CLUSTER_SERIVCE_NAME^^}${NC} ===\n"
  select ANSWER in "Start" "Stop" "Status" "Restart" "Next Service" "Exit"
  do
    case ${ANSWER} in
    "Start")
      cluster_service_start
    ;;
    "Stop")
      cluster_service_stop
    ;;
    "Status")
      cluster_service_status
    ;;
    "Restart")
      cluster_service_restart
    ;;
    "Next Service")
      break
    ;;
    "Exit")
      clear
      exit 0
    ;;
    *) echo -e "\n${RED}Invalid option, please try again${NC}"
       sleep 1
       clear
    esac
  done
done
