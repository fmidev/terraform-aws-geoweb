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
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
      most_recent              = true
    }
    amazon-cloudwatch-observability = {
      most_recent = true
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

  eks_managed_node_groups = {

    default = {
      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      iam_role_name              = "${var.name}-node-role"
      iam_role_use_name_prefix   = false
      use_custom_launch_template = false

      ami_type                   = var.node_ami_type
      platform                   = var.node_platform
      instance_types             = var.node_instance_types
      iam_role_attach_cni_policy = true

      iam_role_additional_policies = {
        CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      }
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
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 96)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 102)]

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

resource "helm_release" "zalando-postgres-operator" {
  count      = var.enableZalandoPostgresOperator ? 1 : 0
  name       = "postgres-operator"
  repository = "https://opensource.zalando.com/postgres-operator/charts/postgres-operator"
  chart      = "postgres-operator"
  namespace  = var.helm_chart_used_namespace
  version    = "1.10.1"

  values = [
    file("${path.module}/helm-configurations/zalando-postgres-operator.yaml")
  ]

  dynamic "set" {
    for_each = var.zalandoOperatorCustomVars

    content {
      name  = set.key
      value = set.value
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_config_map" "pod_config" {
  count = var.enableZalandoPostgresOperator ? 1 : 0
  metadata {
    name      = "pod-config"
    namespace = var.helm_chart_used_namespace
  }

  data = merge(yamldecode(file("${path.module}/helm-configurations/zalando-pod-config.yaml")), var.zalandoPodConfigCustomVars)

  depends_on = [module.eks]
}

resource "helm_release" "zalando-postgres-operator-ui" {
  count      = var.enableZalandoPostgresOperator ? 1 : 0
  name       = "postgres-operator-ui"
  repository = "https://opensource.zalando.com/postgres-operator/charts/postgres-operator-ui"
  chart      = "postgres-operator-ui"
  namespace  = var.helm_chart_used_namespace
  version    = "1.10.1"

  depends_on = [module.eks]
}

module "eks-cluster-autoscaler" {
  source  = "lablabs/eks-cluster-autoscaler/aws"
  version = "2.2.0"

  cluster_identity_oidc_issuer     = module.eks.oidc_provider
  cluster_identity_oidc_issuer_arn = module.eks.oidc_provider_arn
  cluster_name                     = module.eks.cluster_name
  namespace                        = var.helm_chart_used_namespace

  depends_on = [module.eks]
}

################################################################################
# Dynamodb table for locking state
################################################################################

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

################################################################################
# Resources to enable AWS EBS storage class
################################################################################

module "ebs_csi_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name             = "${var.name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "kubernetes_annotations" "gp2_default" {
  annotations = {
    "storageclass.kubernetes.io/is-default-class" : "false"
  }
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata {
    name = "gp2"
  }

  force = true

  depends_on = [module.eks]
}

resource "kubernetes_storage_class" "ebs_csi_encrypted_gp3_storage_class" {
  metadata {
    name = "ebs-csi-encrypted-gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" : "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"
  parameters = {
    fsType    = "ext4"
    encrypted = true
    type      = "gp3"
  }

  depends_on = [kubernetes_annotations.gp2_default]
}

################################################################################
# IAM role used to deploy applications to the cluster
################################################################################

resource "aws_iam_role" "terraform-clusterAdmin-iam-role" {
  name = "${var.name}-clusterAdmin-role"
  assume_role_policy = jsonencode({
    Statement = [{
      "Effect" : "Allow",
      "Principal" : {
        "AWS" : "arn:aws:iam::${module.vpc.vpc_owner_id}:root"
      },
      "Action" : "sts:AssumeRole",
      "Condition" : {}
      },
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "arn:aws:iam::${module.vpc.vpc_owner_id}:oidc-provider/${var.oidcProvider}"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringLike" : {
            "${var.oidcProvider}:aud" : var.oidcAudience,
            "${var.oidcProvider}:sub" : var.oidcAllowedRepositoryAndBranch
          }
        }
      },
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "${module.eks.oidc_provider_arn}"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringLike" : {
            "${module.eks.oidc_provider}:aud" : var.oidcAudience,
            "${module.eks.oidc_provider}:sub" : var.oidcServiceAccounts
          }
        }
      }
    ]
    Version = "2012-10-17"
  })

  tags = local.tags
}

resource "aws_iam_policy" "terraform-clusterAdmin-iam-policy" {
  name        = "${var.name}-clusterAdmin-policy"
  path        = "/"
  description = "${var.name}-clusterAdmin-policy"
  policy = jsonencode({
    Statement = [
      {
        "Effect" : "Allow",
        "Action" : [
          "eks:*",
        ],
        "Resource" : [
          module.eks.cluster_arn,
          module.eks.eks_managed_node_groups["default"].node_group_arn
        ],
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        "Resource" : [
          "arn:aws:secretsmanager:${var.region}:${module.vpc.vpc_owner_id}:secret:*",
        ]
      }
    ]
    Version = "2012-10-17"
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "terraform-clusterAdmin-policy-attachment" {
  policy_arn = aws_iam_policy.terraform-clusterAdmin-iam-policy.arn
  role       = aws_iam_role.terraform-clusterAdmin-iam-role.name
}
