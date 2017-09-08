#!/bin/bash -e

. cloudformation-ecs/jenkins/deploy-scripts/assume-role.sh ${AWS_DEV_ACCOUNT_ID} ${AWS_JENKINS_ROLE}

export TASK_DEFINITION_NAME="${SERVICE_NAME}-${ENV_NAME}"

echo '{
    "containerDefinitions": [
' > service-task-definition.json

IFS=' ' read -r -a array <<< "$CONTAINERS"

last_container="${array[-1]}"

for container in $CONTAINERS;
do
	#Should be parameterized somehow
    cat ${JENKINS_HOME}/metering-${ENV_NAME}/${SERVICE_NAME}-service/${container}/container-definition.json >> service-task-definition.json
    [[ "$container" != "$last_container" ]] && echo "," >> service-task-definition.json
done

echo "]," >> service-task-definition.json

if [[ "$VOLUMES" != "" ]]; then
    echo "${VOLUMES}," >> service-task-definition.json
fi

echo "\"family\": \"${TASK_DEFINITION_NAME}\"
}" >> service-task-definition.json

aws ecs register-task-definition --cli-input-json file://service-task-definition.json

CLUSTER="${ENV_NAME}"
SERVICE_NAME="${SERVICE_NAME}-service-${ENV_NAME}"
SERVICE_STATE=$(aws ecs describe-services --cluster ${CLUSTER} --service ${SERVICE_NAME} | jq -r ".services[].status")
DESIRED_COUNT=${ECS_SERVICE_DESIRED_COUNT:-2}
[[ "$DEPLOY_CONFIG" == "" ]] && DEPLOY_CONFIG="maximumPercent=100,minimumHealthyPercent=50"

if [[ "$SERVICE_STATE" != "ACTIVE" ]]; then
    LOAD_BALANCERS=""

    [[ "$TARGET_GROUP_NAME" == "" ]] && TARGET_GROUP_NAME="$SERVICE_NAME"

    if [[ "$LOAD_BALANCER" != "" ]]; then
        TG_ARN=$(aws elbv2 describe-target-groups | jq -r ".TargetGroups[] | select (.TargetGroupName == \"${TARGET_GROUP_NAME}\") | .TargetGroupArn")
        [[ "${TG_ARN}" == "" ]] && exit 1
        LOAD_BALANCERS="--load-balancers targetGroupArn=${TG_ARN},${LOAD_BALANCER} --role ecs-service-${ENV_NAME}"
    fi

    aws ecs create-service --service-name $SERVICE_NAME --cluster $CLUSTER --desired-count $DESIRED_COUNT --task-definition $TASK_DEFINITION_NAME --deployment-configuration $DEPLOY_CONFIG $LOAD_BALANCERS
else
    aws ecs update-service --service $SERVICE_NAME --cluster $CLUSTER --desired-count $DESIRED_COUNT --task-definition $TASK_DEFINITION_NAME --deployment-configuration $DEPLOY_CONFIG
fi

[[ $ECS_SERVICE_DESIRED_COUNT -eq 0 ]] && exit 0

sleep 30

UPDATE_TIME=$(aws ecs describe-services --cluster $CLUSTER --service $SERVICE_NAME | jq -r ".services[] | select (.serviceName == \"${SERVICE_NAME}\") | .deployments[] | select (.status == \"PRIMARY\") | .updatedAt")
COUNTER=1
SERVICE_STATUS=""

while [[ "${SERVICE_STATUS}" == "" ]]; do
    sleep 30
    SERVICE_STATUS="$(aws ecs describe-services --cluster $CLUSTER --service $SERVICE_NAME | jq -r ".services[] | select (.serviceName == \"${SERVICE_NAME}\") | .events[] | select (.createdAt > ${UPDATE_TIME}) | select (.message | contains(\"steady\")) | .message")"
    ((COUNTER++))
    [[ $COUNTER -gt 30 ]] && exit 1
done

exit 0
