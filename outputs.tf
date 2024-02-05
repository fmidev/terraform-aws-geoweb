output "elastic_ip_address" {
  description = "Elastic IP Address managed by GeoWeb module"
  value       = module.vpc.nat_public_ips[0]
  sensitive   = true
}

output "load_balancer_hostname" {
  description = "Hostname of load balancer created by nginx-ingress-controller"
  value       = data.kubernetes_service.nginx_ingress.status[0].load_balancer[0].ingress[0].hostname
  sensitive   = true
}

output "vpc" {
  description = "Details of resources created by vpc module"
  value       = module.vpc
  sensitive   = true
}

output "eks" {
  description = "Details of resources created by eks module"
  value       = module.eks
  sensitive   = true
}

output "dynamodb_lock" {
  description = "Details of dynamodb table resource"
  value       = aws_dynamodb_table.dynamodb-terraform-state-lock
  sensitive   = true
}

output "helm_metrics_server" {
  description = "Details of metrics-server helm release"
  value       = helm_release.metrics-server
  sensitive   = true
}

output "helm_nginx_ingress_controller" {
  description = "Details of nging-ingress-controller helm release"
  value       = helm_release.nginx-ingress-controller
  sensitive   = true
}

output "helm_secrets_store_csi_driver" {
  description = "Details of secrets-store-csi-driver helm release"
  value       = helm_release.secrets-store-csi-driver
  sensitive   = true
}

output "helm_secrets_store_csi_driver_provider" {
  description = "Details of secrets-store-csi-driver-provider helm release"
  value       = helm_release.secrets-store-csi-driver-provider
  sensitive   = true
}
