# Terraform Cost Optimization Policies
# Validate resource sizing and cost-effective configurations

package terraform.cost

default allow := true

# Warnings for cost optimization (not blocking)
warn contains msg if {
    check_instance_sizes
    msg := "Warning: Large instance types detected - consider right-sizing"
}

warn contains msg if {
    check_storage_optimization
    msg := "Warning: Storage can be optimized"
}

warn contains msg if {
    check_rds_instance_cost
    msg := "Warning: Consider using smaller RDS instance for non-production environments"
}

warn contains msg if {
    check_nat_gateway_optimization
    msg := "Warning: Multiple NAT Gateways increase costs - consider consolidating for non-production"
}

# Check: Instance sizes should be appropriate
check_instance_sizes if {
    some resource in input.resource_changes
    resource.type == "aws_instance"
    is_large_instance(resource.change.after.instance_type)
}

is_large_instance(instance_type) if {
    large_instances := ["t3.2xlarge", "t3.xlarge", "m5.2xlarge", "m5.xlarge"]
    some li in large_instances
    instance_type == li
}

# Check: Storage optimization
check_storage_optimization if {
    some resource in input.resource_changes
    resource.type == "aws_db_instance"
    resource.change.after.allocated_storage > 100
}

# Check: RDS should use cost-effective instance types for dev/staging
check_rds_instance_cost if {
    some resource in input.resource_changes
    resource.type == "aws_db_instance"
    not is_cost_effective_rds(resource.change.after.instance_class)
}

is_cost_effective_rds(instance_class) if {
    cost_effective := ["db.t3.micro", "db.t3.small", "db.t4g.micro", "db.t4g.small"]
    some ce in cost_effective
    instance_class == ce
}

# Check: NAT Gateway optimization
check_nat_gateway_optimization if {
    nat_gateways := [r | some r in input.resource_changes; r.type == "aws_nat_gateway"]
    count(nat_gateways) > 1
}
