# terraform-aws-geoweb

TODO: Transforming this repository to be in a form that it can be published as a public Terraform module.

## Description

Configuration to deploy and update AWS resources and EKS environment.

## Deployment

Deployment is for now, during active development, done manually with `terraform apply -var="certificateARN=arn:aws:acm:<region>:123456789012:certificate/*** -var="accountId=123456789012`

## Connecting to EKS cluster

Terraform creates a role named `terraform-clusterAdmin-iam-role` which can be used to connect & manage the created EKS cluster named `terraform-eks-cluster`.

Prerequisites:
1. Check that you don't have `AWS_SECRET_ACCESS_KEY`, `AWS_ACCESS_KEY_ID` or `AWS_SESSION_TOKEN` environment variables already set with `env | grep AWS`
    * These will be overwritten, so backup if needed
2. Use AWS CloudShell, or if running locally, make sure you have `aws-cli` and `kubectl` installed

Steps to use the role and get the connection to the cluster:
1. To assume `terraform-clusterAdmin-iam-role`, you can run the `assumeClusterAdminRole.sh` script provided with `source assumeClusterAdminRole.sh assume`
    * Change accountId to correct one in the script
2. Running `aws sts get-caller-identity` should now return the `terraform-clusterAdmin-iam-role`
3. Update your kubeconfig with `aws eks --region eu-north-1 update-kubeconfig --name terraform-eks-cluster`
4. Running `kubectl config get-contexts` should now include `terraform-eks-cluster`, you can change current cluster with `kubectl use-context arn:aws:eks:<region>:123456789012:cluster/terraform-eks-cluster`
5. You should now be able to run other `kubectl` commands to communicate with the cluster, like `kubectl get pods -A`
