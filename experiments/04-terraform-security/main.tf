# Experiment 4: Terraform Security Validation
# Simplified Terraform configuration for policy testing

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "db_allocated_storage" {
  description = "RDS storage size in GB"
  type        = number
}

variable "db_engine_version" {
  description = "PostgreSQL version"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Database admin username"
  type        = string
}

variable "db_password" {
  description = "Database admin password"
  type        = string
  sensitive   = true
}

variable "db_storage_encrypted" {
  description = "Enable storage encryption"
  type        = bool
  default     = true
}

variable "db_publicly_accessible" {
  description = "Make database publicly accessible"
  type        = bool
  default     = false
}

variable "db_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "allowed_cidr_blocks" {
  description = "Allowed CIDR blocks for database access"
  type        = list(string)
  default     = []
}

variable "s3_bucket_name" {
  description = "S3 bucket name"
  type        = string
}

variable "s3_enable_encryption" {
  description = "Enable S3 encryption"
  type        = bool
  default     = true
}

variable "s3_block_public_access" {
  description = "Block S3 public access"
  type        = bool
  default     = true
}

variable "create_kms_key" {
  description = "Create KMS key for encryption"
  type        = bool
  default     = true
}

variable "db_monitoring_interval" {
  description = "Enhanced monitoring interval"
  type        = number
  default     = 0
}

variable "db_performance_insights_enabled" {
  description = "Enable performance insights"
  type        = bool
  default     = false
}

variable "db_enabled_cloudwatch_logs_exports" {
  description = "CloudWatch log exports"
  type        = list(string)
  default     = []
}

# Outputs for testing
output "configuration_summary" {
  value = {
    db_encrypted          = var.db_storage_encrypted
    db_public             = var.db_publicly_accessible
    db_backup_retention   = var.db_backup_retention_period
    s3_encrypted          = var.s3_enable_encryption
    s3_public_blocked     = var.s3_block_public_access
    kms_key_created       = var.create_kms_key
    tags_count            = length(var.tags)
    security_cidr_count   = length(var.allowed_cidr_blocks)
  }
}

output "compliance_status" {
  value = {
    encryption_compliant = var.db_storage_encrypted && var.s3_enable_encryption
    access_compliant     = !var.db_publicly_accessible && var.s3_block_public_access
    backup_compliant     = var.db_backup_retention_period >= 7
    tags_compliant       = contains(keys(var.tags), "Environment") && contains(keys(var.tags), "Project") && contains(keys(var.tags), "ManagedBy")
  }
}
