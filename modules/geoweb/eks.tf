resource "aws_iam_role" "terraform-eks-iam-role" {
    name = "terraform-eks-iam-role"
    path = "/"
    assume_role_policy = jsonencode({
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
                Service = "eks.amazonaws.com"
            }
        }]
        Version = "2012-10-17"
    })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    role = aws_iam_role.terraform-eks-iam-role.name
}

resource "aws_iam_role" "terraform-workernode-iam-role" {
    name = "terraform-workernode-iam-role"
    assume_role_policy = jsonencode({
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
                Service = "ec2.amazonaws.com"
            }
        }]
        Version = "2012-10-17"
    })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    role = aws_iam_role.terraform-workernode-iam-role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    role = aws_iam_role.terraform-workernode-iam-role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    role = aws_iam_role.terraform-workernode-iam-role.name
}

resource "aws_iam_role" "terraform-clusterAdmin-iam-role" {
    name = "terraform-clusterAdmin-iam-role"
    assume_role_policy = jsonencode({
        Statement = [{
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${var.accountId}:root"
            },
            "Action": "sts:AssumeRole",
            "Condition": {}
        }]
        Version = "2012-10-17"
    })
}

resource "aws_iam_policy" "terraform-clusterAdmin-iam-policy" {
  name        = "terraform-clusterAdmin-iam-policy"
  path        = "/"
  description = "terraform-clusterAdmin-iam-policy"
  policy = jsonencode({
        Statement = [
            {
                "Effect": "Allow",
                "Action": [
                    "eks:*",
                ],
                "Resource": [
                    aws_eks_cluster.terraform-eks-cluster.arn,
                    aws_eks_node_group.worker-node-group.arn
                ],
            },
        ]
        Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "terraform-clusterAdmin-policy-attachment" {
    policy_arn = aws_iam_policy.terraform-clusterAdmin-iam-policy.arn
    role = aws_iam_role.terraform-clusterAdmin-iam-role.name
}

resource "aws_eks_cluster" "terraform-eks-cluster" {
    name = "terraform-eks-cluster"
    role_arn = aws_iam_role.terraform-eks-iam-role.arn
    vpc_config {
        subnet_ids = [
            aws_subnet.terraform-eks-subnet-public-1a.id,
            aws_subnet.terraform-eks-subnet-public-1b.id,
            aws_subnet.terraform-eks-subnet-private-1a.id,
            aws_subnet.terraform-eks-subnet-private-1b.id
        ]
        security_group_ids = [aws_security_group.terraform-eks-sg.id]
    }
    depends_on = [
        aws_iam_role.terraform-eks-iam-role,
    ]
}

resource "kubernetes_config_map" "aws_auth" {
    metadata {
        name      = "aws-auth"
        namespace = "kube-system"
        labels = {
            "app.kubernetes.io/managed-by" = "Terraform"
        }
    }
    data = {
        # Note: yamlencode adds quotes to the yaml, it doesn't affect functionality
        mapRoles = yamlencode([
            {
                rolearn = aws_iam_role.terraform-workernode-iam-role.arn
                username = "system:node:{{EC2PrivateDNSName}}"
                groups = ["system:bootstrappers", "system:nodes"]
            },
            {
                rolearn = aws_iam_role.terraform-clusterAdmin-iam-role.arn
                username = aws_iam_role.terraform-clusterAdmin-iam-role.name
                groups = ["system:masters"]
            },
        ])
    }
}

resource "null_resource" "aws-cni-configuration" {
    provisioner "local-exec" {
        command = <<EOF
            aws eks --region eu-north-1 update-kubeconfig  --name ${aws_eks_cluster.terraform-eks-cluster.name} &&
            kubectl config use-context ${aws_eks_cluster.terraform-eks-cluster.arn} &&
            kubectl --context ${aws_eks_cluster.terraform-eks-cluster.arn} set env daemonset aws-node -n kube-system ENABLE_PREFIX_DELEGATION=true
        EOF
    }
    depends_on = [
        aws_eks_cluster.terraform-eks-cluster,
        kubernetes_config_map.aws_auth
    ]
}

resource "aws_eks_node_group" "worker-node-group" {
    cluster_name = aws_eks_cluster.terraform-eks-cluster.name
    node_group_name = "terraform-eks-workernodes"
    node_role_arn = aws_iam_role.terraform-workernode-iam-role.arn
    subnet_ids = [
        aws_subnet.terraform-eks-subnet-private-1a.id,
        aws_subnet.terraform-eks-subnet-private-1b.id
    ]
    instance_types = ["t3.medium"]
    scaling_config {
        desired_size = 1
        max_size   = 5
        min_size   = 1
    }
    depends_on = [
        aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
        aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
        aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
        kubernetes_config_map.aws_auth,
        null_resource.aws-cni-configuration
    ]
}

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
        name = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-cert"
        value = var.certificateARN
    }
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
}