variable "aws_region" {
  description = "AWS region for the lab"
  type        = string
  default     = "us-east-1"
}

variable "db_password" {
  description = "Password for the RDS PostgreSQL instance"
  type        = string
  sensitive   = true
}

variable "github_org" {
  description = "GitHub username or organization"
  type        = string
  default     = "DPP-2026"
}

variable "github_org_id" {
  description = "Numeric GitHub org/owner ID"
  type        = string
  default     = "YOUR_ORG_ID"
}

variable "github_repo_ids" {
  description = "Map of repo name to numeric GitHub repo ID"
  type        = map(string)

  default = {
    "zen-pharma-frontend"     = "YOUR_FRONTEND_ID"
    "zen-pharma-backend"      = "YOUR_BACKEND_ID"
    "zen-pharma-backend-lab1" = "YOUR_LAB1_ID"
  }
}