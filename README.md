# terraform-aws-geoweb

## Description

Terraform module for creating AWS resources used by GeoWeb applications.

## Instructions

In order to use full capabilities of terraform-aws-geoweb module, user needs to set a few variables before running `terraform apply`. Variables can be passed to the terraform command in multiple ways, choose what best suits your environment, some examples:

1. Set TF_VAR_variable environment variables
2. Pass variables in the command:
`terraform apply -var="certificateARN=arn:aws:acm:<aws-region>:<aws-account-id>:certificate/<certificate-id>`
3. Using terragrunt inputs block in `terragrunt.hcl` and run `terragrunt apply`:
```
inputs = {
  certificateARN = "arn:aws:acm:<aws-region>:<aws-account-id>:certificate/<certificate-id>"
}

```
## Included helm-charts

### nginx-ingress-controller

Deployment includes configuration for an ingress controller, which is configured to run together with AWS, creating single load balancer which routes traffic from desired domains to deployed GeoWeb applications.

### secrets-store-csi-driver & secrets-store-csi-driver-provider-aws

Deployment includes configuration for Secrets Store CSI Driver + AWS Secrets and Configuration Provider (ASCP) which allows the kubernetes cluster to use secrets from AWS Secret Manager.

### metrics-server

Provides basic resource usage metrics, used manually with `kubectl top node` and `kubectl top pod` and automatically with `cluster-autoscaler`.

### cluster-autoscaler

Monitors the resource usage of the applications in EKS and automatically scales the amount of nodes. Doesn't scale past min_size and max_size defined in the node group. 
* Note that metrics-server can show memory usage values of over 100% (even 130% in extreme cases) which is totally fine and doesn't require scaling. This is because metrics-server reserves a small amount of memory for each possible pod that it doesn't consider in the percentage, and as we have set the maximum number of pods to 110 in vpc-cni, it thinks we have around 1.5G lower memory available per node that we actually have. cluster-autoscaler correctly uses the real amount of memory available.

### zalando-postgres-operator & zalando-postgres-operator-ui

Kubernetes operator that provides the Zalando postgresql database functionality, with extra chart that provides UI for managing it.

## EKS Add-ons installed

### coredns, kube-proxy & vpc-cni

Necessary add-ons that ensure that network inside the EKS cluster work correctly.

* coredns handles dns resolution inside the EKS cluster (so pods can communicate without using direct ip addresses)
* kube-proxy and vpc-cni handles networking

### aws-ebs-csi-driver

Allows PersistentVolumes to be dynamically provisioned using AWS EBS storage. 

Uses role `ebs_csi_irsa_role` and default gp2 storage class is replaced with gp3.

### amazon-cloudwatch-observability

Enables basic AWS CloudWatch logging.

#### Instructions to deploy the module with Zalando Postgres Operator using environment variables

Make sure you are authenticated as the user/role with enough permissions using `aws configure` and optionally `aws sts assume-role`, check your current credentials with `aws sts get-caller-identity`.

For nginx-ingress-controller to work properly, user needs to add certificateARN:
`export TF_VAR_certificateARN=arn:aws:acm:<aws-region>:<aws-account-id>:certificate/<certificate-id>`

As user wants to use Zalando Postgres Operator for their databases, they need to enable it and pass custom variables which should contain at least credentials to connect to S3 bucket used for backups:

```
export TF_VAR_enableZalandoPostgresOperator=true
export TF_VAR_zalandoOperatorCustomVars='{"configLogicalBackup.logical_backup_s3_access_key_id"="<AWS_ACCESS_KEY_ID>","configLogicalBackup.logical_backup_s3_secret_access_key"="<AWS_SECRET_ACCESS_KEY>","configLogicalBackup.logical_backup_s3_bucket"="<S3-bucket-name>","configAwsOrGcp.log_s3_bucket"="<S3-bucket-name>","configAwsOrGcp.wal_s3_bucket"="<S3-bucket-name>"}'
export TF_VAR_zalandoPodConfigCustomVars='{AWS_ACCESS_KEY_ID="<AWS_ACCESS_KEY_ID>",AWS_SECRET_ACCESS_KEY="<AWS_SECRET_ACCESS_KEY>",WALG_S3_PREFIX="s3://<S3-bucket-name>",CLONE_AWS_ACCESS_KEY_ID="<AWS_ACCESS_KEY_ID>",CLONE_AWS_SECRET_ACCESS_KEY="<AWS_SECRET_ACCESS_KEY>",CLONE_WALG_S3_PREFIX="s3://<S3-bucket-name>"}'
```

Run `terraform apply`

## ClusterAdmin role

Default values for OIDC variables are examples for GitHub repositories. Default values allow OIDC control from every GitHub repository. These can be configured to either specific GitHub repositories (recommended when repository is in GitHub) or to different source control systems for example like GitLab. Example values for configuring GitLab as the OIDC provider would be `gitlab.com` for the oidcProvider variable and `project_path:<organization>/<repository>:ref_type:branch:ref:<branch>`. Other repositories can also be used.