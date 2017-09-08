# Description

The Docker container that is used for Let'sEncrypt certificate generation/renewal and ALB listener creation.
[Dehydrated](https://github.com/lukas2511/dehydrated) is used as ACME client, *awscli* is used to manipulate AWS resources.

**File structure:**

* [assume-role](assume-role) - bash script for assuming AWS role;
* [config](config) - main dehydrated config;
* [dehydrated-dns-custom](dehydrated-dns-custom) - bash script with dehydrated hooks;
* [docker-entrypoint](docker-entrypoint) - bash script used as Docker entrypoint;
* [update-certificates](update-certificates) - bash script used as Docker `CMD`.

# Workflow

- Docker entrypoint gets executed on container's start up;
- default `CMD` starts update-certificates script with infinite loop;
- IAM role is assumed, Let'sEncrypt accounts and certificates sync from S3, dehydrated starts;
- for each dehydrated event (deploy/clean challenge, deploy/unchanged certificate) corresponding hook gets executed from dehydrated-dns-custom;
- challenge is deployed via DNS TXT records (Route53);
- deploy certificate hook creates HTTPS ELBv2 listener and deletes old SSL certificate.

**Main environmental variables:**

- `AWS_ROLE` - AWS IAM role to be assumed;
- `AWS_DEV_ACCOUNT_ID` - AWS `development` account id;
- `AWS_DNS_ACCOUNT_ID` - AWS `dns` account id;
- `ENV_NAME` - environment name;
- `ROUTE53_ZONE` - main domain;
- `LOAD_BALANCER_NAME` - ALB used for HTTPS listener creation;
- `TARGET_GROUP_NAME` - target group used for HTTPS listener creation;
- `S3_BUCKET_NAME` - S3 bucket name for Let'sEncrypt accounts and certificates storage.
