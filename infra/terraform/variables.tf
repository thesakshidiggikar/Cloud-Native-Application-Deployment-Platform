variable "aws_region" {
  description = "AWS deployment region; set in ignored terraform.tfvars."
  type        = string
  nullable    = false
  validation {
    condition     = length(var.aws_region) > 0 && var.aws_region != "CHANGE_ME"
    error_message = "Set aws_region in an ignored tfvars file before planning."
  }
}
variable "project_name" {
  type    = string
  default = "devopshere"
}
variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}
variable "vpc_cidr" {
  type    = string
  default = "10.40.0.0/16"
}
variable "kubernetes_version" {
  type    = string
  default = "1.34"
}
variable "cluster_admin_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint. Never use 0.0.0.0/0."
  type        = list(string)
  default     = []
  validation {
    condition     = length(var.cluster_admin_cidrs) > 0 && !contains(var.cluster_admin_cidrs, "0.0.0.0/0")
    error_message = "Provide explicit trusted admin CIDRs; public access to all IPv4 is rejected."
  }
}
variable "single_nat_gateway" {
  description = "Cheaper lab topology; a single NAT reduces AZ resilience."
  type        = bool
  default     = true
}
variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}
variable "node_min_size" {
  type    = number
  default = 2
}
variable "node_max_size" {
  type    = number
  default = 4
}
variable "node_desired_size" {
  type    = number
  default = 2
}
variable "database_instance_class" {
  type    = string
  default = "db.t4g.micro"
}
variable "database_allocated_storage_gib" {
  type    = number
  default = 20
}
variable "database_max_allocated_storage_gib" {
  type    = number
  default = 100
}
variable "database_multi_az" {
  type    = bool
  default = false
}
variable "database_backup_retention_days" {
  type    = number
  default = 7
}
variable "postgres_engine_version" {
  type    = string
  default = "16.6"
}
variable "cache_node_type" {
  type    = string
  default = "cache.t4g.micro"
}
variable "cache_nodes" {
  type    = number
  default = 1
}
variable "redis_engine_version" {
  type    = string
  default = "7.1"
}
variable "tags" {
  type    = map(string)
  default = { Application = "devopshere" }
}
