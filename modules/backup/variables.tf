# Tagging Variables
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "acme"
}

variable "owner" {
  description = "Owner/team responsible for resources"
  type        = string
  default     = "platform"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    "managed-by" = "terraform"
  }
}

variable "enable_backup" {
  description = "Enable Velero backup and disaster recovery"
  type        = bool
  default     = true
}

variable "velero_namespace" {
  description = "Namespace for Velero"
  type        = string
  default     = "velero"
}

variable "velero_release_name" {
  description = "Helm release name for Velero"
  type        = string
  default     = "velero"
}

variable "velero_repository" {
  description = "Helm repository for Velero"
  type        = string
  default     = "https://vmware-tanzu.github.io/helm-charts"
}

variable "velero_chart" {
  description = "Helm chart name for Velero"
  type        = string
  default     = "velero"
}

variable "velero_chart_version" {
  description = "Helm chart version for Velero"
  type        = string
  default     = "5.0.0"
}

variable "velero_storage_location" {
  description = "Storage location for backups (local, aws, azure, gcp)"
  type        = string
  default     = "local"
}

variable "velero_backup_storage_bucket" {
  description = "Bucket name for backup storage"
  type        = string
  default     = "velero-backups"
}

variable "velero_snapshot_location" {
  description = "Storage location for volume snapshots"
  type        = string
  default     = "local"
}

variable "velero_enable_snapshots" {
  description = "Enable volume snapshots"
  type        = bool
  default     = true
}

variable "velero_cpu_request" {
  description = "CPU request for Velero"
  type        = string
  default     = "500m"
}

variable "velero_memory_request" {
  description = "Memory request for Velero"
  type        = string
  default     = "128Mi"
}

variable "velero_cpu_limit" {
  description = "CPU limit for Velero"
  type        = string
  default     = "1000m"
}

variable "velero_memory_limit" {
  description = "Memory limit for Velero"
  type        = string
  default     = "512Mi"
}

variable "velero_backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}

variable "velero_schedule_database_backup" {
  description = "Enable scheduled database backups"
  type        = bool
  default     = true
}

variable "velero_database_backup_schedule" {
  description = "Cron schedule for database backups (default: daily at 2 AM UTC)"
  type        = string
  default     = "0 2 * * *"
}

variable "velero_schedule_config_backup" {
  description = "Enable scheduled application config backups"
  type        = bool
  default     = true
}

variable "velero_config_backup_schedule" {
  description = "Cron schedule for config backups (default: daily at 3 AM UTC)"
  type        = string
  default     = "0 3 * * *"
}

variable "backup_namespaces" {
  description = "List of namespaces to back up"
  type        = list(string)
  default     = ["application", "database"]
}

variable "velero_aws_credentials_secret" {
  description = "AWS credentials secret name (if using AWS S3)"
  type        = string
  default     = ""
}
