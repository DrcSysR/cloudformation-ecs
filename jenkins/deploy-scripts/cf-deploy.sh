#!/bin/bash

set -e

function get-stack-status
{
    echo "$(aws cloudformation describe-stacks --stack-name "${ENV_NAME}" | jq -r ".Stacks[].StackStatus")"
}

. jenkins/deploy-scripts/assume-role.sh ${AWS_DEV_ACCOUNT_ID} ${AWS_JENKINS_ROLE}

if [ $DESTROY == "true" ]; then
    STACK_STATUS=$(get-stack-status)

    CLUSTER_NAME="${ENV_NAME}"

    for service in $(aws ecs list-services --cluster ${CLUSTER_NAME} | jq -r ".serviceArns[]"); do
        aws ecs update-service --cluster ${CLUSTER_NAME} --service ${service} --desired-count 0
    done

    for task in $(aws ecs list-tasks --cluster ${CLUSTER_NAME} | jq -r ".taskArns[]"); do
        aws ecs stop-task --cluster ${CLUSTER_NAME} --task ${task}
    done

    sleep 30

    for service in $(aws ecs list-services --cluster ${CLUSTER_NAME} | jq -r ".serviceArns[]"); do
        aws ecs delete-service --cluster ${CLUSTER_NAME} --service ${service}
    done

    for instance in $(aws ecs list-container-instances --cluster ${CLUSTER_NAME} | jq -r ".containerInstanceArns[]"); do
        aws ecs deregister-container-instance --cluster ${CLUSTER_NAME} --container-instance ${instance}
    done

    aws s3 rb s3://storage-${ENV_NAME} --force

    aws cloudformation delete-stack --stack-name $ENV_NAME

    while true; do
        sleep 30
        STACK_STATUS=$(get-stack-status)
        echo "${STACK_STATUS}"
        if [[ "${STACK_STATUS}" == "DELETE_FAILED" ]]; then
            exit 1
        elif [[ "${STACK_STATUS}" == "" ]]; then
            break
        fi
    done

    echo "Cloudformation stack $ENV_NAME has been destroyed!"

    # DNS Account stack

    . $WORKSPACE/jenkins/deploy-scripts/assume-role.sh ${AWS_DNS_ACCOUNT_ID} ${AWS_JENKINS_ROLE} discard

    aws cloudformation delete-stack --stack-name $ENV_NAME

    while true; do
        sleep 30
        STACK_STATUS=$(get-stack-status)
        echo "${STACK_STATUS}"
        if [[ "${STACK_STATUS}" == "DELETE_FAILED" ]]; then
            exit 1
        elif [[ "${STACK_STATUS}" == "" ]]; then
            break
        fi
    done

    echo "Cloudformation DNS stack $ENV_NAME has been destroyed!"

    exit 0
fi

ENV_VARS=""
for var in $(env | cut -f1 -d= | grep -E -v '^_'); do ENV_VARS="$ENV_VARS \${${var}}"; done

for item in $(find . -type f -name "*.yaml" | cut -c 3-) ; do
    envsubst "${ENV_VARS}" < $item > $item-new
    mv $item-new $item
    aws cloudformation validate-template --template-body file://$item
	aws s3 cp $item s3://$s3_bucket/$item
done

TYPE="UPDATE"

if aws cloudformation describe-stacks --stack-name $ENV_NAME; then
    aws cloudformation update-stack --template-body file://main.yaml --stack-name $ENV_NAME  --capabilities  CAPABILITY_NAMED_IAM
else
    TYPE="CREATE"
    aws cloudformation create-stack --template-body file://main.yaml --stack-name $ENV_NAME  --capabilities  CAPABILITY_NAMED_IAM --disable-rollback

fi

while true; do
    sleep 30
    STACK_STATUS=$(get-stack-status)
    echo "${STACK_STATUS}"
    if [[ "${STACK_STATUS}" == "${TYPE}_FAILED" ]]; then
        exit 1
    elif [[ "${STACK_STATUS}" == "${TYPE}_COMPLETE" ]]; then
        break
    elif [[ "${STACK_STATUS}" == "UPDATE_ROLLBACK_COMPLETE" ]]; then
        exit 2
    fi
done

export ALB_URL=$(aws cloudformation list-exports | jq -r '.Exports[] | select(.Name== "'"alb-url-$ENV_NAME"'").Value')

# DNS Account stack

. $WORKSPACE/jenkins/deploy-scripts/assume-role.sh ${AWS_DNS_ACCOUNT_ID} ${AWS_JENKINS_ROLE} discard

ROUTE53_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "${ROUTE53_ZONE}" --max-items 1 | jq -r ".HostedZones[].Id")
export ROUTE53_ZONE_ID="${ROUTE53_ZONE_ID#/hostedzone/}"

envsubst '${ROUTE53_ZONE_ID} ${ALB_URL}' < main-dns.yaml > main-dns.yaml.new
mv main-dns.yaml.new main-dns.yaml

if aws cloudformation describe-stacks --stack-name $ENV_NAME; then
    aws cloudformation update-stack --template-body file://main-dns.yaml --stack-name $ENV_NAME 2> /tmp/aws-stderr || ret=$?
    if [[ "$(cat /tmp/aws-stderr)" == "An error occurred (ValidationError) when calling the UpdateStack operation: No updates are to be performed." ]]; then
        exit 0
    fi
else
    ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "${ROUTE53_ZONE}" --max-items 1 | jq -r ".HostedZones[].Id")
    RECORD=$(aws route53 list-resource-record-sets --hosted-zone-id ${ZONE_ID} | jq -r '.ResourceRecordSets[] | select(.Name == "${ENV_NAME}.${ROUTE53_ZONE}.")')

    if [[ "$RECORD" != "" ]]; then
        echo "$RECORD" | jq '.|{"Changes":[.|{"Action":"DELETE","ResourceRecordSet":.}]}' > /tmp/batch.json
        aws route53 change-resource-record-sets --hosted-zone-id ${ZONE_ID} --change-batch file:///tmp/batch.json
    fi

    aws cloudformation create-stack --template-body file://main-dns.yaml --stack-name $ENV_NAME --disable-rollback
fi
