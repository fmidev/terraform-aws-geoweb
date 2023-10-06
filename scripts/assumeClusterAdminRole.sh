#!/bin/bash

if [ "$1" == "assume" ]; then
  ROLE_ARN=arn:aws:iam::123456789012:role/terraform-clusterAdmin-iam-role
  ROLE_SESSION_NAME=eksAdminSession

  CREDENTIALS=$(aws sts assume-role --role-arn $ROLE_ARN --role-session-name $ROLE_SESSION_NAME)

  export AWS_ACCESS_KEY_ID=$(echo $CREDENTIALS | jq -r '.Credentials.AccessKeyId')
  export AWS_SECRET_ACCESS_KEY=$(echo $CREDENTIALS | jq -r '.Credentials.SecretAccessKey')
  export AWS_SESSION_TOKEN=$(echo $CREDENTIALS | jq -r '.Credentials.SessionToken')
elif [ "$1" == "forget" ]; then
  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
  unset AWS_SESSION_TOKEN
else
  echo "Invalid parameter. Please use 'assume' or 'forget'."
fi