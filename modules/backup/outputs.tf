output "velero_namespace" {
  description = "Velero namespace"
  value       = var.enable_backup ? kubernetes_namespace.velero[0].metadata[0].name : ""
}

output "velero_enabled" {
  description = "Velero backup enabled"
  value       = var.enable_backup
}

output "velero_release_name" {
  description = "Velero Helm release name"
  value       = var.enable_backup ? helm_release.velero[0].name : ""
}

output "velero_release_status" {
  description = "Velero Helm release status"
  value       = var.enable_backup ? helm_release.velero[0].status : ""
}

output "velero_release_version" {
  description = "Velero Helm chart version"
  value       = var.enable_backup ? helm_release.velero[0].version : ""
}

output "velero_storage_location" {
  description = "Velero backup storage location"
  value       = var.velero_storage_location
}

output "velero_backup_bucket" {
  description = "Velero backup storage bucket"
  value       = var.velero_backup_storage_bucket
}

output "velero_snapshots_enabled" {
  description = "Volume snapshots enabled"
  value       = var.velero_enable_snapshots
}

output "velero_backup_retention_days" {
  description = "Backup retention period in days"
  value       = var.velero_backup_retention_days
}

output "velero_get_backups_command" {
  description = "Command to list Velero backups"
  value       = var.enable_backup ? "kubectl get backups -n ${kubernetes_namespace.velero[0].metadata[0].name}" : ""
}

output "velero_get_schedules_command" {
  description = "Command to list Velero backup schedules"
  value       = var.enable_backup ? "kubectl get schedules -n ${kubernetes_namespace.velero[0].metadata[0].name}" : ""
}

output "velero_get_restore_command" {
  description = "Command to list Velero restores"
  value       = var.enable_backup ? "kubectl get restores -n ${kubernetes_namespace.velero[0].metadata[0].name}" : ""
}

output "velero_describe_backup_command" {
  description = "Command to describe a Velero backup"
  value       = var.enable_backup ? "kubectl describe backup <backup-name> -n ${kubernetes_namespace.velero[0].metadata[0].name}" : ""
}

output "velero_restore_command" {
  description = "Command to restore from a Velero backup"
  value       = var.enable_backup ? "velero restore create --from-backup <backup-name> --wait" : ""
}

output "database_backup_schedule" {
  description = "Database backup schedule (cron)"
  value       = var.velero_database_backup_schedule
}

output "config_backup_schedule" {
  description = "Application config backup schedule (cron)"
  value       = var.velero_config_backup_schedule
}
