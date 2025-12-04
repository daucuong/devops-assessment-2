# Common Tagging Variables (used by all modules)
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

variable "cost_center" {
  description = "Cost center for billing purposes"
  type        = string
  default     = "engineering"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    "managed-by"  = "terraform"
    "created-by"  = "devops-team"
  }
}
