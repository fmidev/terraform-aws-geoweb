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
  cluster_version = "1.27"
  vpc_cidr        = "10.3.0.0/16"

  # eu-north-1 has 3 AZs, if the region used has different amount of AZs, adjust this number
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

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
  cluster_version                = local.cluster_version
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
  aws_auth_roles = [
    {
      rolearn  = aws_iam_role.terraform-clusterAdmin-iam-role.arn
      username = aws_iam_role.terraform-clusterAdmin-iam-role.name
      groups   = ["system:masters"]
    },
  ]

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

    # Default node group - as provided by AWS EKS using Bottlerocket
    bottlerocket_default = {
      iam_role_name              = "${var.name}-bottlerocket-node-role"
      iam_role_use_name_prefix   = false
      use_custom_launch_template = false

      ami_type = "BOTTLEROCKET_x86_64"
      platform = "bottlerocket"
    }
  }

  tags = local.tags
}

################################################################################
# IAM role to allow manual access to EKS cluster
################################################################################

resource "aws_iam_role" "terraform-clusterAdmin-iam-role" {
  name = "terraform-clusterAdmin-iam-role"
  assume_role_policy = jsonencode({
    Statement = [{
      "Effect" : "Allow",
      "Principal" : {
        "AWS" : "arn:aws:iam::${var.accountId}:root"
      },
      "Action" : "sts:AssumeRole",
      "Condition" : {}
    }]
    Version = "2012-10-17"
  })

  tags = local.tags
}

resource "aws_iam_policy" "terraform-clusterAdmin-iam-policy" {
  name        = "terraform-clusterAdmin-iam-policy"
  path        = "/"
  description = "terraform-clusterAdmin-iam-policy"
  policy = jsonencode({
    Statement = [
      {
        "Effect" : "Allow",
        "Action" : [
          "eks:*",
        ],
        "Resource" : [
          module.eks.cluster_arn,
          module.eks.eks_managed_node_groups["bottlerocket_default"].node_group_arn
        ],
      },
    ]
    Version = "2012-10-17"
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "terraform-clusterAdmin-policy-attachment" {
  policy_arn = aws_iam_policy.terraform-clusterAdmin-iam-policy.arn
  role       = aws_iam_role.terraform-clusterAdmin-iam-role.name
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 4.0"

  name = var.name
  cidr = local.vpc_cidr

  azs = local.azs
  # cidrsubnet function docs can be found here: https://developer.hashicorp.com/terraform/language/functions/cidrsubnet
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 52)]

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
  namespace  = "kube-system"
  version    = "4.7.2"

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
    namespace = "kube-system"
    name      = "nginx-ingress-controller-ingress-nginx-controller"
  }

  depends_on = [helm_release.nginx-ingress-controller]
}

output "nginx-ingress-controller-hostname" {
  value = data.kubernetes_service.nginx_ingress.status[0].load_balancer[0].ingress[0].hostname
}

resource "helm_release" "secrets-store-csi-driver" {
  name       = "secrets-store-csi-driver"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  namespace  = "kube-system"
  version    = "1.3.4"

  values = [
    file("${path.module}/helm-configurations/secrets.yaml")
  ]
  depends_on = [module.eks]
}

resource "helm_release" "secrets-store-csi-driver-provider-aws" {
  name       = "secrets-store-csi-driver-provider-aws"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  namespace  = "kube-system"
  version    = "0.3.4"

  values = [
    file("${path.module}/helm-configurations/secrets.yaml")
  ]
  depends_on = [module.eks]
}

resource "helm_release" "metrics-server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.11.0"

  values = [
    file("${path.module}/helm-configurations/metrics.yaml")
  ]
  depends_on = [module.eks]
}
