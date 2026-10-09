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
  default     = "geethak5513"
}

variable "github_org_id" {
  description = "Numeric GitHub org/owner ID"
  type        = string
  default     = "41056499"
}

variable "github_repo_ids" {
  description = "Map of repo name to numeric GitHub repo ID"
  type        = map(string)

  default = {
    "zen-pharma-frontend" = "1411328384"
    "zen-pharma-backend"  = "1389434853"
  }
}
