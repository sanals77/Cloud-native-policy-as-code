# Kubernetes Security Policies
# Validate Kubernetes manifests for security best practices

package kubernetes.security

# Default deny
default allow := false

# Allow if all checks pass
allow if {
    count(deny) == 0
}

# Collect all violations
deny contains msg if {
    input.kind == "Deployment"
    not has_security_context
    msg := sprintf("Deployment %v must have securityContext defined", [input.metadata.name])
}

deny contains msg if {
    input.kind == "Deployment"
    some container in input.spec.template.spec.containers
    not container.securityContext.runAsNonRoot
    msg := sprintf("Container %v must run as non-root user", [container.name])
}

deny contains msg if {
    input.kind == "Deployment"
    some container in input.spec.template.spec.containers
    not container.securityContext.readOnlyRootFilesystem
    msg := sprintf("Container %v must have read-only root filesystem", [container.name])
}

deny contains msg if {
    input.kind == "Deployment"
    some container in input.spec.template.spec.containers
    container.securityContext.privileged
    msg := sprintf("Container %v must not run in privileged mode", [container.name])
}

deny contains msg if {
    input.kind == "Deployment"
    not has_resource_limits
    msg := sprintf("Deployment %v must have resource limits defined", [input.metadata.name])
}

deny contains msg if {
    input.kind == "Deployment"
    not has_liveness_probe
    msg := sprintf("Deployment %v must have liveness probe", [input.metadata.name])
}

deny contains msg if {
    input.kind == "Deployment"
    not has_readiness_probe
    msg := sprintf("Deployment %v must have readiness probe", [input.metadata.name])
}

deny contains msg if {
    input.kind == "Service"
    input.spec.type == "LoadBalancer"
    not has_allowed_ips
    msg := sprintf("Service %v of type LoadBalancer must restrict source IPs", [input.metadata.name])
}

deny contains msg if {
    input.kind == "Deployment"
    some container in input.spec.template.spec.containers
    has_latest_tag(container.image)
    msg := sprintf("Container %v must not use 'latest' tag", [container.name])
}

# Helper functions
has_security_context if {
    input.spec.template.spec.securityContext
}

has_resource_limits if {
    some container in input.spec.template.spec.containers
    container.resources.limits
}

has_liveness_probe if {
    some container in input.spec.template.spec.containers
    container.livenessProbe
}

has_readiness_probe if {
    some container in input.spec.template.spec.containers
    container.readinessProbe
}

has_allowed_ips if {
    input.spec.loadBalancerSourceRanges
}

has_latest_tag(image) if {
    endswith(image, ":latest")
}

has_latest_tag(image) if {
    not contains(image, ":")
}

# Secret Management
deny contains msg if {
    input.kind == "Deployment"
    some container in input.spec.template.spec.containers
    some env in container.env
    is_sensitive_env_var(env.name)
    not env.valueFrom.secretKeyRef
    msg := sprintf("Sensitive environment variable %v in container %v must use secretKeyRef", [env.name, container.name])
}

is_sensitive_env_var(name) if {
    sensitive_patterns := ["PASSWORD", "SECRET", "TOKEN", "KEY", "CREDENTIAL"]
    upper_name := upper(name)
    some pattern in sensitive_patterns
    contains(upper_name, pattern)
}
