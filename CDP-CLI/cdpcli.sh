#!/usr/bin/env bash

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#| Validating the roles for the user from cdp cli            |
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# To check if cdp cli installed or not.


if ! cdp --version > /dev/null 2>&1 ; 
  then 
  	echo "CDP CLI  is not installed"; 
  else 
  	version=`cdp --version`
  	echo "you have CDP cli installed and the version is $version"
fi

 # To check if cdp cli installed or not.


 
#if ! grep cdp_access_key_id ~/.cdp/credentials; then
 #  if ! grep cdp_private_key ~/.cdp/credentials; then
 #  echo "AWS config not found or you don't have AWS CLI installed"
  # else 
   #echo "CDP CLI configured properly"
    #  exit 1
   #fi
#fi

## Getting the User details from CDP CLI 

USER=`cdp iam get-user |grep -i firstName | awk -F ':' '{print $(NF-0)}' | tr -d '", '`

echo "Please wait while validating the roles for $USER ..........\n" 


sleep 4

## Getting the User details from CDP CLI 

LUSER=`cdp iam list-users --max-items 10000|jq '.users[] |  select(.firstName=='\"$USER\"')'| awk '{print $2}' |head -3 | grep -i crn | tr -d '",'`

PER=`cdp iam list-user-assigned-roles --user $LUSER  | grep  crn |awk -F ':' '{print $(NF-0)}'| grep Environment |tr -d '",'`

echo "Your user $USER having the following roles"

echo $PER\n
