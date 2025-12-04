# Non-Compliant Infrastructure Configuration
# ⚠️ FOR DEMONSTRATION PURPOSES ONLY - Contains intentional policy violations

# VPC Configuration
vpc_cidr     = "10.0.0.0/16"
environment  = "test"
project_name = "policy-violation-test"

# RDS Configuration - NON-COMPLIANT
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
db_engine_version    = "14.7"
db_name              = "testdb"
db_username          = "dbadmin"
db_password          = "TestPassword123!"  # ❌ Hardcoded password

# ❌ VIOLATION: Storage encryption disabled
db_storage_encrypted = false

# ❌ VIOLATION: Database publicly accessible
db_publicly_accessible = true

# ❌ VIOLATION: No backup retention
db_backup_retention_period = 0

# ❌ VIOLATION: Missing required tags
tags = {
  Name = "test-database"
  # Missing: Environment, Project, ManagedBy
}

# Security Group - NON-COMPLIANT
# ❌ VIOLATION: Allows unrestricted access
allowed_cidr_blocks = ["0.0.0.0/0"]

# S3 Configuration - NON-COMPLIANT
s3_bucket_name = "test-bucket-noncompliant"

# ❌ VIOLATION: No encryption configuration
s3_enable_encryption = false

# ❌ VIOLATION: Public access not blocked
s3_block_public_access = false

# KMS - Not configured
# ❌ VIOLATION: No KMS key for encryption
create_kms_key = false

# Monitoring - Insufficient
# ❌ VIOLATION: No enhanced monitoring
db_monitoring_interval = 0

# ❌ VIOLATION: No performance insights
db_performance_insights_enabled = false

# ❌ VIOLATION: Limited log exports
db_enabled_cloudwatch_logs_exports = []
