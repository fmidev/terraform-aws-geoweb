variable "certificateARN" {
  type = string
}

variable "name" {
  type    = string
  default = "geoweb"
}

variable "region" {
  type    = string
  default = "eu-north-1"
}

variable "lock_name" {
  type    = string
  default = "default-dynamodb-terraform-state-lock"
}

variable "cluster_version" {
  type    = string
  default = "1.34"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "node_min_size" {
  type    = string
  default = "1"
}

variable "node_max_size" {
  type    = string
  default = "5"
}

variable "node_desired_size" {
  type    = string
  default = "1"
}

variable "node_ami_type" {
  type    = string
  default = "BOTTLEROCKET_x86_64"
}

variable "node_platform" {
  type    = string
  default = "bottlerocket"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "helm_chart_used_namespace" {
  type    = string
  default = "kube-system"
}

variable "nginx_ingress_controller_version" {
  type    = string
  default = "4.15.1"
}

variable "secrets_store_csi_driver_version" {
  type    = string
  default = "1.6.0"
}

variable "secrets_store_csi_driver_provider_version" {
  type    = string
  default = "3.1.0"
}

variable "metrics_server_version" {
  type    = string
  default = "3.11.0"
}

variable "zalandoPodConfigCustomVars" {
  type    = map(string)
  default = {}
}

variable "zalandoOperatorCustomVars" {
  type    = map(string)
  default = {}
}

variable "enableZalandoPostgresOperator" {
  type    = bool
  default = false
}

variable "oidcProvider" {
  type    = string
  default = "token.actions.githubusercontent.com"
}

variable "oidcAllowedRepositoryAndBranch" {
  type    = string
  default = "repo:*/*:ref:refs/heads/*"
}

variable "oidcServiceAccounts" {
  type    = list(string)
  default = ["system:serviceaccount:*:*"]
}

variable "oidcAudience" {
  type    = string
  default = "sts.amazonaws.com"
}
