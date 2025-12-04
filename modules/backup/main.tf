# Velero Namespace
resource "kubernetes_namespace" "velero" {
  count = var.enable_backup ? 1 : 0
  metadata {
    name = var.velero_namespace
    labels = {
      "app.kubernetes.io/component" = "backup"
    }
  }
}

# Velero Helm Release
resource "helm_release" "velero" {
  count      = var.enable_backup ? 1 : 0
  name       = var.velero_release_name
  repository = var.velero_repository
  chart      = var.velero_chart
  namespace  = kubernetes_namespace.velero[0].metadata[0].name
  version    = var.velero_chart_version

  values = [
    yamlencode({
      configuration = {
        backupStorageLocation = {
          name     = "default"
          provider = var.velero_storage_location
          bucket   = var.velero_backup_storage_bucket
          config = {
            localPath = "/var/velero/backups"
          }
        }
        volumeSnapshotLocation = {
          name     = "default"
          provider = var.velero_snapshot_location
          config = {
            localPath = "/var/velero/backups"
          }
        }
        schedules = {
          # Database backup schedule
          "daily-db-backup" = {
            schedule = var.velero_database_backup_schedule
            template = {
              includedNamespaces = ["database"]
              includedResources = [
                "persistentvolumeclaims",
                "persistentvolumes"
              ]
              labelSelector = {
                matchLabels = {
                  "app.kubernetes.io/component" = "database"
                }
              }
              storageLocation = "default"
              ttl             = "${var.velero_backup_retention_days * 24}h0m0s"
              volumeSnapshotLocations = [
                "default"
              ]
            }
          }
          # Application config backup schedule
          "daily-config-backup" = {
            schedule = var.velero_config_backup_schedule
            template = {
              includedNamespaces = var.backup_namespaces
              includedResources = [
                "configmaps",
                "secrets",
                "deployments",
                "services",
                "ingresses"
              ]
              excludedResources = [
                "pods",
                "events",
                "replicasets",
                "jobs",
                "cronjobs"
              ]
              storageLocation = "default"
              ttl             = "${var.velero_backup_retention_days * 24}h0m0s"
            }
          }
        }
      }
      snapshotsEnabled = var.velero_enable_snapshots
      credentials = {
        useSecret = false
      }
      resources = {
        requests = {
          cpu    = var.velero_cpu_request
          memory = var.velero_memory_request
        }
        limits = {
          cpu    = var.velero_cpu_limit
          memory = var.velero_memory_limit
        }
      }
      podAnnotations = {
        "prometheus.io/scrape" = "true"
        "prometheus.io/port"   = "8085"
      }
    })
  ]

  depends_on = [kubernetes_namespace.velero]
}
