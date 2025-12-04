output "nginx_ingress_namespace" {
  description = "NGINX Ingress namespace"
  value       = kubernetes_namespace.ingress_nginx.metadata[0].name
}

output "nginx_ingress_release_name" {
  description = "NGINX Ingress release name"
  value       = helm_release.nginx_ingress.name
}

output "app_ingress_name" {
  description = "Application ingress resource name"
  value       = kubernetes_ingress_v1.app_ingress.metadata[0].name
}

output "app_ingress_status" {
  description = "Application ingress status with load balancer IP"
  value       = kubernetes_ingress_v1.app_ingress.status[0]
}
