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

variable "enable_monitoring" {
  description = "Enable Prometheus and Grafana monitoring"
  type        = bool
  default     = true
}

variable "monitoring_namespace" {
  description = "Namespace for monitoring"
  type        = string
  default     = "monitoring"
}

# Prometheus Variables
variable "prometheus_name" {
  description = "Name of Prometheus Helm release"
  type        = string
  default     = "prometheus"
}

variable "prometheus_repository" {
  description = "Helm repository for Prometheus"
  type        = string
  default     = "https://prometheus-community.github.io/helm-charts"
}

variable "prometheus_chart" {
  description = "Helm chart for Prometheus"
  type        = string
  default     = "kube-prometheus-stack"
}

variable "prometheus_version" {
  description = "Version of Prometheus chart"
  type        = string
  default     = "56.0.0"
}

variable "prometheus_cpu_request" {
  description = "CPU request for Prometheus"
  type        = string
  default     = "250m"
}

variable "prometheus_memory_request" {
  description = "Memory request for Prometheus"
  type        = string
  default     = "512Mi"
}

variable "prometheus_cpu_limit" {
  description = "CPU limit for Prometheus"
  type        = string
  default     = "500m"
}

variable "prometheus_memory_limit" {
  description = "Memory limit for Prometheus"
  type        = string
  default     = "1Gi"
}

# Grafana Variables
variable "grafana_enabled" {
  description = "Enable Grafana"
  type        = bool
  default     = true
}

variable "grafana_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = "admin"
}
