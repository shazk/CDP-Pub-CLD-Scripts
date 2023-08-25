#!/usr/bin/env bash
################################################################################################################################
# Through API and systemctl commands, this script checks the status of the following services                                   |                    
# -> Nginx                                                                                                                      |
# -> CM server and CM agent                                                                                                     |  
# -> Knox Service                                                                                                               |
# It will collect the service logs if any of the above services are not running or are in poor health.                          |
# This script needs to run from the CM node as the root.                                                                        |       
# Requires a Workload user and password.                                                                                        |
################################################################################################################################
# v1.1
# Created By = Shehbaz
# Modified By = Raman
# Colour Code Used = Red          31     Green        32     Cyan         36

# Define Variables
clear
unset tecreset
tecreset=$(tput sgr0)
DATE=
NCHECK="OK"
CMCHECK="OK"
CMACHECK="OK"
KCHECK="OK"

# Exporting CM DB properties
export CM_SERVER_DB_FILE=/etc/cloudera-scm-server/db.properties
export CM_DB_HOST=$(awk -F"=" '/db.host/ {print $NF}' ${CM_SERVER_DB_FILE})
export CM_DB_NAME=$(awk -F"=" '/db.name/ {print $NF}' ${CM_SERVER_DB_FILE})
export CM_DB_USER=$(awk -F"=" '/db.user/ {print $NF}' ${CM_SERVER_DB_FILE})
export PGPASSWORD=$(awk -F"=" '/db.password/ {print $NF}' ${CM_SERVER_DB_FILE})
export CM_CLUSTER_NAME=$(echo -e "SELECT name FROM clusters;" | psql -h ${CM_DB_HOST} -U ${CM_DB_USER} -d ${CM_DB_NAME} | grep -v Proxy | tail -n 3 | head -n1| sed 's| ||g')
export CM_SERVER="https://$(hostname -f):7183"
export CM_API_VERSION=$(curl -s -L -k -u ${WORKLOAD_USER}:${WORKLOAD_USER_PASS} -X GET "${CM_SERVER}/api/version")

# Prompt user for credentials
read -p "Please enter your Workload username: "  WORKLOAD_USER
unset WORKLOAD_USER_PASS
unset CHARTCOUNT

echo -n "Please enter your Workload user password: "
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

# Define Variable tecreset
tecreset=$(tput sgr0)

# Functions
# Test credentials
function do_test_credentials () {
  curl -s -L -k -u ${WORKLOAD_USER}:${WORKLOAD_USER_PASS} -X GET "${CM_SERVER}/api/version" > /tmp/null 2>&1
  if grep "Bad credentials" /tmp/null > /dev/null 2>&1
  then
    CRED_VALIDATED=1
    echo -n -e '\E[31m'"\n#####The Credentials that you have entered are incorrect, Please Check them once.\n" $tecreset
    rm -rf /tmp/null
  else
    CRED_VALIDATED=0
    rm -rf /tmp/null
  fi

  if [[ ${CRED_VALIDATED} == 0 ]]
  then
    export CM_API_VERSION=$(curl -s -L -k -u ${WORKLOAD_USER}:${WORKLOAD_USER_PASS} -X GET "${CM_SERVER}/api/version")
  else
 exit 1
fi
}


# Function for Nginx check
function do_nginx_check () {
    # Print separator line
    echo "------------------------------------------------------"

    # Print status message
    echo -n -e '\E[33m'"\n##### Validating the Nginx service status.\n" $tecreset

    # Check Nginx's status using systemctl
    nginx_status="$(systemctl is-active nginx)"

    # If Nginx is running fine
    if [ "$nginx_status" = "active" ]
    then
        # Print success message
        echo -n -e '\E[32m'"\n##### The Nginx service is running fine.\n" $tecreset
        # Print separator line
        echo "--------------------------------------------------------"
    else
        # If Nginx is not running, capture logs if in failed state and restart it
        # Print error message
        echo -n -e '\E[31m'"\n##### The Nginx service is not running or in failed state.\n" $tecreset
        # Print information message
        echo -n -e '\E[36m'"\n##### Please wait, while collecting logs.....\n" $tecreset

        # Command to collect the Knox serivce logs
        tar cz --hard-dereference --dereference -f /tmp/nginx-service-log-files-$(hostname -f)_$(date +%m%d%H%M%S).tgz /var/log/{nginx}  2>/dev/null
        NFILENAME=`ls -ltr /tmp | grep -i nginx-service-log | awk '{print $9}' | sort -t'-' -k1nr | head -1`
        # Wait for 3 seconds
        sleep 3
        # Print error message
        echo -n -e '\E[31m'"\n##### Please attach the below log file present under \"/tmp\" dir to the Case:\n" $tecreset
        # Print separator line
        echo "-------------------------------------------------------------------------------------------------------------------"
        # Print log file path
        echo "/tmp/$NFILENAME"
        # Print separator line
        echo " -------------------------------------------------------------------------------------------------------------------"
    fi

    # Wait for 3 seconds before checking again
    sleep 3
}

# Function For CM Check
function do_cm_server_check () {
    echo -n -e '\E[33m'"\n##### Validating the CM server\n" $tecreset

    # Get CM server state using cdp-doctor and remove color codes from the output
    CMSTATE=$(cdp-doctor service status | grep -i cm-server | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g" | awk '{print $2}' | tr -d "[]")

    # Check if CM server is running fine or not
    if [[ "$CMCHECK" == "$CMSTATE" ]]; then
        echo -n -e '\E[32m'"\n##### The CM server is running fine\n" $tecreset
        echo "--------------------------------------------------------"
    else
        echo " "
        echo -n -e '\E[31m'"\n##### The CM server is not running." $tecreset
        echo -n -e '\E[36m'"\n##### Please wait, while Collecting logs of the CM service....." $tecreset

        # Command to collect CM server logs
        tar cz --hard-dereference --dereference -f /tmp/cm-server-files-$(hostname -f)_$(date +%m%d%H%M%S).tgz /etc/default/cloudera-scm-server /etc/cloudera-scm-agent /var/log/{cloudera-scm-agent,cloudera-scm-alertpublisher,cloudera-scm-eventserver,cloudera-scm-firehose,cloudera-scm-server} /var/run/cloudera-scm-agent/process/*-cloudera-mgmt-{ALERTPUBLISHER,EVENTSERVER,HOSTMONITOR,SERVICEMONITOR}/{*.properties,*.conf,logs}  2>/dev/null

        sleep 3

        # Get the latest log file name
        CMFILENAME=$(ls -ltr /tmp | grep -i cm-server-files | awk '{print $9}' | sort -t'-' -k1nr | head -1)
        echo -n -e '\E[31m'"\n##### The CM server is not running, Please reach out to Cloudera Support\n" $tecreset
        echo -n -e '\E[31m'"\n##### Please attach the below log file present under "/tmp" dir to the Case\n" $tecreset
        echo "-------------------------------------------------------------------------------------------------------------------"
        echo "$CMFILENAME"
        echo "-------------------------------------------------------------------------------------------------------------------"
    fi
}

# Function to validate the CM agent
function do_cm_agent_check() {
  # Print message to console
   echo -n -e '\E[33m'"\n##### Validating the CM agent\n" $tecreset

  # Get status of CM agent service and remove escape characters
  CMASTATE=`cdp-doctor service status | grep -i cm-agent | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g" | awk '{print $2}' | tr -d "[]"`

  # Check if CM agent is running fine
  if [[ "$CMACHECK" == "NOK" ]]; then
    # Print message to console
    echo -n -e '\E[32m'"\n##### The CM agent is running fine\n" $tecreset
    echo "------------------------------------------------------"
  else
    # Print message to console
    echo -n -e '\E[31m'"\n##### The CM agent is not running." $tecreset
    echo -n -e '\E[36m'"\n##### Please wait, while Collecting logs of the CM service....." $tecreset

    # Check status of CM agent on other node using salt command
    source activate_salt_env
    salt '*' cmd.run "systemctl status cloudera-scm-agent" 2>/dev/null | sed '1,2d' > /tmp/cloudera_scm_agents_status_$(hostname)_$(date +%m%d%H%M%S).out
    deactivate

    # Collect CM agent service logs
    tar cz --hard-dereference --dereference -f /tmp/cm-agent-files-$(hostname -f)_$(date +%m%d%H%M%S).tgz /etc/default/cloudera-scm-server /etc/cloudera-scm-agent /var/log/{cloudera-scm-agent,cloudera-scm-alertpublisher,cloudera-scm-eventserver,cloudera-scm-firehose,cloudera-scm-server} /var/run/cloudera-scm-agent/process/*-cloudera-mgmt-{ALERTPUBLISHER,EVENTSERVER,HOSTMONITOR,SERVICEMONITOR}/{*.properties,*.conf,logs}  2>/dev/null

    # Wait for 3 seconds
    sleep 3

    # Get latest log file names
    CMAFILENAME=`ls -ltr /tmp | grep -i cm-agent-files | awk '{print $9}' | sort -t'-' -k1nr | head -1`
    CMASTATUSFILENAME=`ls -ltr /tmp | grep -i cloudera_scm_agents | awk '{print $9}' | sort -t'-' -k1nr | head -1`

    # Print error message to console
    echo -n -e '\E[31m'"\n##### The CM agent is not running, Please reach out to Cloudera Support\n" $tecreset
    echo -n -e '\E[31m'"##### Please attach the below log file present under "/tmp" dir to the Case\n" $tecreset
    echo "-------------------------------------------------------------------------------------------------------------------"
    echo "$CMAFILENAME"
    echo "$CMASTATUSFILENAME"
    echo "-------------------------------------------------------------------------------------------------------------------"
  fi
}

# Function to check the Knox service status
function do_knox_check (){
  
  # Print message to validate Knox service status
  echo -n -e '\E[33m'"\n##### Validating the Knox Service Status.\n" $tecreset

  # Get the Knox service status
  KSTATE=`cdp-doctor service status | grep -i knox | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g" | awk '{print $2}' | tr -d "[]"`

  # Check if Knox service is running fine
  if [[ "$KCHECK" == "$KSTATE" ]]; then
    # Knox service is running fine
    echo -n -e '\E[32m'"\n##### The Knox service is running fine.\n" $tecreset
    echo "--------------------------------------------------------"
  else
    # Knox service is not running
    echo " "
    echo -n -e '\E[31m'"\n##### The Knox service is not running." $tecreset
    echo -n -e '\E[36m'"\n##### Please wait, Collecting logs & restarting the Knox service.....\n" $tecreset

    # Command to collect the Knox serivce logs
    tar cz --hard-dereference --dereference -f /tmp/knox-service-log-Files-$(hostname -f)_$(date +%m%d%H%M%S).tgz /var/log/{knox,nginx} /var/lib/knox/gateway/data/security/keystores/ 2>/dev/null

    # Get the latest log file name
    KFILENAME=`ls -ltr /tmp | grep -i "knox-service-log" | awk '{print $9}' | sort -t'-' -k1nr | head -1`
    sleep 7

    echo -n -e '\E[31m'"\n##### The Knox is not running, Please reach out to Cloudera Support" $tecreset
    echo -n -e '\E[31m'"\n##### Please attach the below log file present under "/tmp" dir to the Case.\n" $tecreset
    echo "-------------------------------------------------------------------------------------------------------------------"
    echo "$KFILENAME"
    echo "-------------------------------------------------------------------------------------------------------------------"
 fi
}

# calling all function one by one
do_test_credentials
do_nginx_check
do_cm_server_check
do_cm_agent_check
do_knox_check

unset tecreset
