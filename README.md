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