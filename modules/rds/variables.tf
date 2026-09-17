variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "db_subnet_group_name" {
  type = string
}

variable "eks_node_security_group_id" {
  type = string
}

variable "db_name" {
  type    = string
  default = "pharmadb"
}

variable "username" {
  type = string
}

variable "password" {
  type      = string
  sensitive = true
}

variable "password_version" {
  type    = number
  default = 1
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  type    = bool
  default = true
}

variable "backup_retention_period" {
  type    = number
  default = 0
}

variable "deletion_protection" {
  type    = bool
  default = false
}