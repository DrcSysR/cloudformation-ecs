Table of Contents
=================

* [Description](#description)
* [How-to](#how-to)
* [Workflow](#workflow)

# Description

The CloudFormation nested stack template to deploy an ECS cluster with automatic DNS provisioning on Route53. The CF stack definition is divided into incremental parts. This allows to have a logically defined architecture template, that can be easily modified with stack components.

**Template structure:**

* [main.yaml](main.yaml) - master template that defines the resource stacks to be deployed
* [vpc.yaml](vpc.yaml) - VPC resource stack definition
* [sg.yaml](sg.yaml) - Security Group resource stack definition
* [ecs.yaml](ecs.yaml) - ECS auto-scaling cluster resource stack definition
* [alb.yaml](alb.yaml) - ALB resource stack definition
* [main-dns.yaml](main-dns.yaml) - Route53 resource stack definition

The documentation below provides templates definition overview, general requirements, and variables description to build, update and destroy CF-provisioned ECS stack.

# How-to

This example operates within the following assumptions:
- the latest version of [AWS cli](https://github.com/aws/aws-cli/releases) installed;
- AWS credentials and an SSH key-pair exist;
- AWS credentials have permissions to manage provisioned resources.

The CloudFormation deployment is managed ove a Jenkins build with job with the following parameters"

**Infrastructure variables description:**

- `AWS_ACCOUNT_ID` - AWS account ID
- `AWS_DEV_ACCOUNT_ID` - AWS development account ID
- `AWS_DNS_ACCOUNT_ID` - AWS DNS account ID
- `AWS_JENKINS_ROLE` - Jenkins IAM automation role
- `AWS_DEFAULT_REGION` - AWS region
- `ENV_NAME` - environment name to deploy
- `COMMIT` - GIT commit hash or branch identifier of
- `s3_bucket` - S3 bucket to store CloudFormation stack definitions
- `DESTROY` - variable set to "true" will destroy the stack
- `VPC_CIDR` - VPC CIDR to deploy ECS cluster
- `PublicSubnet1CIDR` - CIDR for the public subnet in the 1st AZ
- `PublicSubnet2CIDR` - CIDR for the public subnet in the 2nd AZ
- `InstanceType` - EC2 instance type to run in ECS cluster
- `ClusterSize` - ECS cluster size
- `EC2_KEYPAIR` - EC2 key-pair to use for EC2 launch configuration
- `ROUTE53_ZONE` - an application domain


The deployment will take about 10-15 minutes to complete depending on the usual factors.

The infrastructure can be destroyed with `DESTROY` variable set to "true".

Jenkins CF deployment job has `--disable-rollback` value set to *true*, that prevents deployment rollback, which is default CloudFromation behaviour. CloudFormation doesn't support state tracking of failed deployments, you will need to check event log to determinate the cause of the issue and delete stack manually.

# Workflow

- Jenkins assumes role in development account.

- A VPC using the specified `ENV_NAME` is being created, with 2 public subnets, and IGW with associated route table.

- Security groups are being created with SSH and HTTP(S) traffic from anywhere, by default.

- The ALB is being created with http listener and a single default target group.

- Empty ECS cluster is being created with IAM roles, instance profile (as well as their respective policies), auto-scaling group with the latest ECS AMI and custom launch configuration to manage scaling events in ECS cluster, log group and main target groups.

- S3 bucket for common storage is being created.

- Deployment script waits for successful creation of main stack.

- Jenkins assumes role in AWS DNS account.

- Route53 DNS record is being created via CF stack (main-dns.yaml).
