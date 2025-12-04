resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = var.ingress_namespace
  }
}

resource "helm_release" "nginx_ingress" {
  name       = var.nginx_ingress_name
  repository = var.nginx_ingress_repository
  chart      = var.nginx_ingress_chart
  namespace  = kubernetes_namespace.ingress_nginx.metadata[0].name
  version    = var.nginx_ingress_version

  values = [
    yamlencode({
      controller = {
        service = {
          type = var.nginx_service_type
        }
        resources = {
          requests = {
            cpu    = var.nginx_cpu_request
            memory = var.nginx_memory_request
          }
          limits = {
            cpu    = var.nginx_cpu_limit
            memory = var.nginx_memory_limit
          }
        }
      }
    })
  ]
}

resource "kubernetes_ingress_v1" "app_ingress" {
  metadata {
    name      = var.ingress_name
    namespace = var.app_namespace
    annotations = {
      "nginx.ingress.kubernetes.io/proxy-connect-timeout" = "600"
      "nginx.ingress.kubernetes.io/proxy-send-timeout"    = "600"
      "nginx.ingress.kubernetes.io/proxy-read-timeout"    = "600"
      "nginx.ingress.kubernetes.io/proxy-body-timeout"    = "600"
    }
  }

  spec {
    ingress_class_name = "nginx"

    # Single host rule with path-based routing
    rule {
      host = "www.acme.com"

      http {
        # API Route: /api/* -> acme-api service
        path {
          path      = "/api"
          path_type = "Prefix"

          backend {
            service {
              name = "acme-api"
              port {
                name = "http"
              }
            }
          }
        }

        # UI Route: / -> acme service (catch-all)
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "acme"
              port {
                name = "http"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.nginx_ingress]
}
