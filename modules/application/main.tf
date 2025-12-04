resource "kubernetes_namespace" "app" {
  count = var.create_namespace ? 1 : 0
  metadata {
    name = var.app_namespace
  }
}

resource "helm_release" "application" {
  name      = var.release_name
  chart     = var.chart_path
  namespace = var.app_namespace

  values = [
    yamlencode({
      image = {
        repository = var.image_repository
        tag        = var.image_tag
        pullPolicy = var.image_pull_policy
      }
      replicaCount = var.replicas
      service = {
        type = var.service_type
        port = var.service_port
      }
      ingress = {
        enabled           = var.enable_ingress
        className         = var.ingress_class
        annotations       = var.ingress_annotations
        hosts             = var.enable_ingress ? var.ingress_hosts : []
        tls               = var.ingress_tls
      }
      resources = {
        requests = {
          cpu    = var.cpu_request
          memory = var.memory_request
        }
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
      }
      env = var.environment_variables
    })
  ]

  depends_on = [kubernetes_namespace.app]
}
