# Output common labels that can be referenced by other modules
output "common_labels" {
  description = "Common labels to apply to resources"
  value = {
    "environment"       = var.environment
    "project"           = var.project_name
    "owner"             = var.owner
    "cost-center"       = var.cost_center
    "managed-by"        = "terraform"
    "created-by"        = "devops-team"
  }
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}

output "owner" {
  description = "Owner/team"
  value       = var.owner
}
