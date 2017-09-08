#!/bin/bash -e

. cloudformation-ecs-devops/jenkins/deploy-scripts/assume-role.sh ${AWS_DEV_ACCOUNT_ID} ${AWS_JENKINS_ROLE}

eval $(aws ecr get-login)

export CONTAINER_NAME=$JOB_BASE_NAME

ECR_HOST="${AWS_DEV_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
REPOSITORY_PREFIX="${ENV_NAME}"
REPOSITORY_NAME="${REPOSITORY_PREFIX}/${CONTAINER_NAME}"
REPOSITORY_PATH="${ECR_HOST}/${REPOSITORY_NAME}"

export IMAGE="${ECR_HOST}/${REPOSITORY_PREFIX}/${CONTAINER_NAME}:${GIT_COMMIT}"

envsubst < exported-parameters.json > exported-parameters-subst.json

PARAMETERS="$(cat exported-parameters-subst.json)"

if ! aws ecr describe-repositories --registry-id $AWS_DEV_ACCOUNT_ID --repository-names $REPOSITORY_NAME;
then
    aws ecr create-repository --repository-name $REPOSITORY_NAME
fi

envsubst <cloudformation-ecs/jenkins/container-definitions/${CONTAINER_NAME}.json > container-definition.json

cd ${CONTAINER_NAME}

if [[ "$CUSTOM_PARAMETERS" != "" ]];
then
    echo "ENV ${CUSTOM_PARAMETERS}" >> Dockerfile
fi

KEYS="$(echo "$PARAMETERS" | jq -r '.[].key')"

for key in $KEYS;
do
    value="$(echo "$PARAMETERS" | jq ".[] | select (.key == \"$key\").value")"
    echo "ENV ${key}=${value}" >> Dockerfile
done

declare -a tags=("latest" "$GIT_COMMIT")

docker build . -t ${REPOSITORY_PATH}:${tags[0]} -t ${REPOSITORY_PATH}:${tags[1]}

for tag in "${tags[@]}";
do
    docker push ${REPOSITORY_PATH}:$tag
done

docker rmi ${REPOSITORY_PATH}:${tags[1]} || true
