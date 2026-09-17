variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "oidc_provider_url" {
  type = string
}

variable "aws_account_id" {
  type = string
}

variable "github_org" {
  type = string
}

variable "github_org_id" {
  type = string
}

variable "github_repo_ids" {
  type = map(string)
}