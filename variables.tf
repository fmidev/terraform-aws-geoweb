variable "certificateARN" {
  type = string
}

variable "accountId" {
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
