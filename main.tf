terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.67.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11.0"
    }
  }
  required_version = ">= 1.5.3"
}

data "aws_availability_zones" "available" {}

locals {
  # Most regions have 3 AZs, if the region used has more AZs and you want to utilize all of them, adjust this number
  azs = slice(data.aws_availability_zones.available.names, 0, length(data.aws_availability_zones.available.names))

  tags = {
    DeploymentName = var.name
    GithubRepo     = "terraform-aws-geoweb"
    GithubOrg      = "fmidev"
  }
}

provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command     = "aws"
    }
  }
}

################################################################################
# EKS Module
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "v19.16.0"

  cluster_name                   = var.name
  cluster_version                = var.cluster_version
  cluster_endpoint_public_access = true

  iam_role_name            = "${var.name}-cluster-role"
  iam_role_use_name_prefix = false

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  manage_aws_auth_configmap = true

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = ["t3.medium"]

    # We are using the IRSA created below for permissions
    # However, we have to deploy with the policy attached FIRST (when creating a fresh cluster)
    # and then turn this off after the cluster/node group is created. Without this initial policy,
    # the VPC CNI fails to assign IPs and nodes cannot join the cluster
    # See https://github.com/aws/containers-roadmap/issues/1666 for more context
    iam_role_attach_cni_policy = true
  }

  eks_managed_node_groups = {

    default = {
      min_size     = var.node_min_count
      max_size     = var.node_max_count
      desired_size = var.node_desired_count

      iam_role_name              = "${var.name}-node-role"
      iam_role_use_name_prefix   = false
      use_custom_launch_template = false

      ami_type = var.node_ami_type
      platform = var.node_platform
    }
  }

  tags = local.tags
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 4.0"

  name = var.name
  cidr = var.vpc_cidr

  azs = local.azs
  # cidrsubnet function docs can be found here: https://developer.hashicorp.com/terraform/language/functions/cidrsubnet
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 52)]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  create_egress_only_igw = true

  tags = local.tags
}

################################################################################
# Installed Helm-Charts
################################################################################

resource "helm_release" "nginx-ingress-controller" {
  name       = "nginx-ingress-controller"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = var.helm_chart_used_namespace
  version    = var.nging_ingress_controller_version

  values = [
    file("${path.module}/helm-configurations/nginx-ingress-controller.yaml"),
  ]
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-cert"
    value = var.certificateARN
  }
  depends_on = [module.eks]
}

data "kubernetes_service" "nginx_ingress" {
  metadata {
    namespace = var.helm_chart_used_namespace
    name      = "nginx-ingress-controller-ingress-nginx-controller"
  }

  depends_on = [helm_release.nginx-ingress-controller]
}

resource "helm_release" "secrets-store-csi-driver" {
  name       = "secrets-store-csi-driver"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  namespace  = var.helm_chart_used_namespace
  version    = var.secrets_store_csi_driver_version

  values = [
    file("${path.module}/helm-configurations/secrets.yaml")
  ]
  depends_on = [module.eks]
}

resource "helm_release" "secrets-store-csi-driver-provider" {
  name       = "secrets-store-csi-driver-provider-aws"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  namespace  = var.helm_chart_used_namespace
  version    = var.secrets_store_csi_driver_provider_version

  values = [
    file("${path.module}/helm-configurations/secrets.yaml")
  ]
  depends_on = [module.eks]
}

resource "helm_release" "metrics-server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = var.helm_chart_used_namespace
  version    = var.metrics_server_version

  values = [
    file("${path.module}/helm-configurations/metrics.yaml")
  ]
  depends_on = [module.eks]
}

resource "aws_dynamodb_table" "dynamodb-terraform-state-lock" {
  name           = var.lock_name
  hash_key       = "LockID"
  read_capacity  = 20
  write_capacity = 20

  attribute {
    name = "LockID"
    type = "S"
  }
}
