locals {
  common_labels = merge(
    var.common_tags,
    {
      "app.kubernetes.io/name"       = "acme-database"
      "app.kubernetes.io/component"  = "database"
      "app.kubernetes.io/managed-by" = "terraform"
      "environment"                  = var.environment
      "project"                      = var.project_name
      "owner"                        = var.owner
    }
  )
}

resource "kubernetes_namespace" "database" {
  metadata {
    name = var.database_namespace
    labels = merge(
      local.common_labels,
      {
        "namespace-purpose" = "database-services"
      }
    )
  }
}
