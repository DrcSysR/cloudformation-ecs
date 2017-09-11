Jenkins CD  pipeline
=================

### Description

This continuous delivery pipeline configured as a multi-SCM parametrized Jenkins job. The build is triggered by GitHub webhook push event. The primary build script `ecs-deploy.sh` performs next steps to deploy an application version to the ECS cluster:
- checkout SCM for each of microservices to an isolated subfolder;
- assume specified role in development account;
- check and create ECR repository, if it doesn't exist in the current AWS region for a specific application container;
- build Docker container image with the latest GIT revision of the source code for all of microservices and push it to appropriate ECR registries;
- register a new task definition version for each of the ECS services;
- initializes ECS service creation or rolling-update;
- waits for "steady" service event.

In most cases, the build will run automatically as a post-push event Jenkins job

### Build parameters/Environment variables

As was mentioned above, this Jenkins CD pipeline uses a set of predefined parameters to substitute variables in ECS task definitions and adapt them to a specific deployment environment or an application development stage. The job can be easily cloned and shared across multiply environments.  


The below is a list of parameters/environment variables used in a Jenkins job:

**Infrastructure variables description:**

- `AWS_ACCOUNT_ID` - AWS account ID;
- `AWS_DEV_ACCOUNT_ID` - AWS development account ID;
- `AWS_DNS_ACCOUNT_ID` - AWS dns account ID;
- `AWS_JENKINS_ROLE` - jenkins will assume this role in development and dns accounts;
- `AWS_DEFAULT_REGION` - AWS region;
- `ENV_NAME` - environment name to deploy;
- `UI_COMMIT` - GIT commit hash or branch identifier of UI component;
- `API_COMMIT` - GIT commit hash or branch identifier of API compoenent;

**ECS task definitions variables descrition:**

- `ECS_SERVICE_DESIRED_COUNT` - Default desired count for each ECS service.
- `MONGO_DB_HOST` - MongoDB endpoint;
- `MONGO_DB_PORT` - MongoDB TCP connection port;
- `MONGO_DB_NAME` - MongoDB database name;
- `MONGO_DB_USER` - MongoDB username;
- `MONGO_DB_PASSWORD` - MongoDB user password;
- `NODE_ENV` - Nodejs NPM deployment stage;
- `SERVICE_URL` - Root path to Service URL.
- `SERVICE_CORE_API` - Local API Endpoint.
- `ROUTE53_ZONE` - Application domain.
- `MYSQL_PORT_3306_TCP_ADDR` - MySQL endpoint (127.0.01 by default);
- `MYSQL_PORT_3306_TCP_PORT` - MySQL port (3306 by default);
- `MYSQL_ENV_MYSQL_ROOT_PASSWORD` - MySQL root password.
