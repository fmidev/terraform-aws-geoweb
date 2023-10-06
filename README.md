# terraform-aws-geoweb

## Description

Terraform module for creating AWS resources used by GeoWeb applications.

## Deployment

Deployment is for now, during active development, done manually with `terraform apply -var="certificateARN=arn:aws:acm:<region>:123456789012:certificate/*** -var="accountId=123456789012 -var="name=<name_of_your_cluster>"`

## Connecting to EKS cluster

Terraform creates a role named `terraform-clusterAdmin-iam-role` which can be used to connect & manage the created EKS cluster named `<name_of_your_cluster>`.

Prerequisites:
1. Check that you don't have `AWS_SECRET_ACCESS_KEY`, `AWS_ACCESS_KEY_ID` or `AWS_SESSION_TOKEN` environment variables already set with `env | grep AWS`
    * These will be overwritten, so backup if needed
2. Use AWS CloudShell, or if running locally, make sure you have `aws-cli` and `kubectl` installed

Steps to use the role and get the connection to the cluster:
1. To assume `terraform-clusterAdmin-iam-role`, you can run the `scripts/assumeClusterAdminRole.sh` script provided with `source scripts/assumeClusterAdminRole.sh assume`
    * Change accountId to correct one in the script
2. Running `aws sts get-caller-identity` should now return the `terraform-clusterAdmin-iam-role`
3. Update your kubeconfig with `aws eks --region eu-north-1 update-kubeconfig --name <name_of_your_cluster>`
4. Running `kubectl config get-contexts` should now include `<name_of_your_cluster>`, you can change current cluster with `kubectl use-context arn:aws:eks:<region>:123456789012:cluster/<name_of_your_cluster>`
5. You should now be able to run other `kubectl` commands to communicate with the cluster, like `kubectl get pods -A`
