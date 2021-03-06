#!/bin/bash

ACCOUNT_ID="$1"
ROLE="${2:-automation}"
DISCARD="$3"

# Discard assigned role
if [[ "$DISCARD" != "" ]]; then
    export AWS_ACCESS_KEY_ID=${OLD_AWS_ACCESS_KEY_ID}
    export AWS_SECRET_ACCESS_KEY=${OLD_AWS_SECRET_ACCESS_KEY}
    unset AWS_SESSION_TOKEN
fi

# Save old access to discard role if needed
export OLD_AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export OLD_AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}

STS_OUTPUT=$(aws sts assume-role --output json --role-arn arn:aws:iam::${ACCOUNT_ID}:role/${ROLE} --role-session-name ${ENV_NAME})

export AWS_ACCESS_KEY_ID=$(echo ${STS_OUTPUT} | jq -r ".Credentials.AccessKeyId")
export AWS_SECRET_ACCESS_KEY=$(echo ${STS_OUTPUT} | jq -r ".Credentials.SecretAccessKey")
export AWS_SESSION_TOKEN=$(echo ${STS_OUTPUT} | jq -r ".Credentials.SessionToken")
