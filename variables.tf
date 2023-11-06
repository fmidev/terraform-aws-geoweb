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

variable "awsAccessKeyId" {
  type = string
}

variable "awsAccessKeySecret" {
  type = string
}

variable "lock_name" {
  type    = string
  default = "default-dynamodb-terraform-state-lock"
}

variable "cluster_version" {
  type    = string
  default = "1.28"
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

variable "nging_ingress_controller_version" {
  type    = string
  default = "4.7.2"
}

variable "secrets_store_csi_driver_version" {
  type    = string
  default = "1.3.4"
}

variable "secrets_store_csi_driver_provider_version" {
  type    = string
  default = "0.3.4"
}

variable "metrics_server_version" {
  type    = string
  default = "3.11.0"
}

variable "zalandoBackupBucket" {
  type = string
}

variable "zalandoBackupRegion" {
  type    = string
  default = "eu-north-1"
}

variable "zalandoCustomVars" {
  type    = map(string)
  default = {}
}
