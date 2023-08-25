#!/usr/bin/env bash

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#| Validating the roles for the user from cdp cli            |
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

clear

read -p "Please enter the Environment CRN of Cluster: "  CLR_CRN

USE=`echo $CLR_CRN |awk -F ':' '{print $(NF-0)}'`

# To check if cdp cli installed or not.

echo "\nPlease wait while we are checking CDP CLI installed or not"

sleep 2

#### cdp version check #####

function do_cdp_version_check (){
if ! cdp --version > /dev/null 2>&1 ;
  then
    echo -n -e "\nCDP CLI  is not installed\n";
    echo -n -e "\nPlease follow the below steps to install the CDP CLI\n"
    echo -n -e "\nSteps --> Sign in to the CDP console --> Click on Help --> Click on Donwload CLI option\n"
  else
    version=`cdp --version`
    echo "\nYou have CDP cli installed and the version is $version"
fi
}

do_cdp_version_check

## Getting the User Name from CDP CLI

USER_NAME=`cdp iam get-user |grep -i firstName | awk -F ':' '{print $(NF-0)}' | tr -d '", '`

echo "\nPlease wait while validating the roles for user $USER_NAME......"

#sleep 4

## Getting the User CRN details from CDP CLI

USER_CRN=`cdp iam list-users --max-items 10000|jq '.users[] |  select(.firstName=='\"$USER_NAME\"')'| awk '{print $2}' |head -3 | grep -i crn | tr -d '",'`

## Getting the User assigned roles details from CDP CLI

echo "\nThe user $USER_NAME having the following Account Roles:\n"

cdp iam list-user-assigned-roles --user $USER_CRN | grep  crn |awk -F ':' '{print $(NF-0)}'| grep Environment |tr -d '",'

## Getting the User resource roles details from CDP CLI

RROLE=`cdp iam  list-user-assigned-resource-roles --user $USER_CRN  | grep -A1 $USE |awk -F ':' '{print $(NF-0)}'|tr -d '",'`

if [[ -z "$RROLE" ]]; then
  echo "\nThe user $USER_NAME is not having any Resource Roles on given Environment";
  echo "\nThe Environment resource roles can be assigned from:"
  echo "\nThe Management Console > Environments > navigate to a specific environment > Actions > Manage Access > Assigned EnvironmentUser Role."
  echo "\nAnd perform Synchronize Users. Once status is Completed kindly try to access the CM UI"
else
  echo "\nThe user $USER_NAME having the following Resource Roles on given Environment:\n";
  echo $RROLE
fi

echo ""
