# Terraform Security Policies for Infrastructure as Code
# These policies validate Terraform plans before deployment

package terraform.security

# Default deny
default allow := false

# Allow if all checks pass
allow if {
    count(deny) == 0
}

# Collect all violations
deny contains msg if {
    check_encrypted_storage
    msg := "Violation: Unencrypted storage detected"
}

deny contains msg if {
    check_public_access
    msg := "Violation: Public access to sensitive resources detected"
}

deny contains msg if {
    check_security_groups
    msg := "Violation: Overly permissive security group rules detected"
}

# Check: All storage must be encrypted
check_encrypted_storage if {
    some resource in input.resource_changes
    resource.type == "aws_db_instance"
    not resource.change.after.storage_encrypted
}

check_encrypted_storage if {
    some resource in input.resource_changes
    resource.type == "aws_ebs_volume"
    not resource.change.after.encrypted
}

# Check: No public access to databases
check_public_access if {
    some resource in input.resource_changes
    resource.type == "aws_db_instance"
    resource.change.after.publicly_accessible == true
}

# Check: Security groups should not allow unrestricted access to sensitive ports
check_security_groups if {
    some resource in input.resource_changes
    resource.type == "aws_security_group"
    some rule in resource.change.after.ingress
    some cidr in rule.cidr_blocks
    cidr == "0.0.0.0/0"
    is_sensitive_port(rule.from_port)
}

# Helper: Identify sensitive ports
is_sensitive_port(port) if {
    sensitive_ports := [22, 3389, 3306, 5432, 6379, 27017]
    some sp in sensitive_ports
    port == sp
}

# Check: RDS should have backup retention
deny contains msg if {
    check_rds_backups
    msg := "Violation: RDS backup retention period too short"
}

check_rds_backups if {
    some resource in input.resource_changes
    resource.type == "aws_db_instance"
    resource.change.after.backup_retention_period < 7
}
