#  DevOps code for ECS stack with Node.js microservice provisioning

This  DevOps code is following an *infrastructure as a code* paradigm. The workflow is designed to keep environment versioned through the whole application lifecycle. The repository consists of infrastructure stack, represented by the AWS ECS cluster and continuous delivery pipeline, build on top of the Jenkins CI.

The Node.js microservice consists of 2 components -  UI and API that being deployed as Docker containers to ECS.

### Overview

The repository has a logically structured folders view. Each folder contains **README.md** with a detailed description of the stack component inside.

### Repository structure

- [cloudformation](cloudformation) - CloudFormation stack template definition.
- [docker-letsencrypt](docker-letsencrypt) - Docker container for generating and updating Let'sEncrypt certificates.
- [ecr-cleanup-lambda](https://github.com/awslabs/ecr-cleanup-lambda/tree/master) - AWS Lambda for cleaning up ECR repositories.
- [jenkins](jenkins) - Jenkins continuous delivery pipeline.
- [nginx-proxy](nginx-proxy) - Nginx reverse proxy for microservices interaction.
