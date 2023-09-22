output "cluster_name" {
  description = "The name of the EKS Cluster created"
  value       = try(aws_eks_cluster.terraform-eks-cluster.name, null)
}