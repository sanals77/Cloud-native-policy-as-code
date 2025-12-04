#!/usr/bin/env python3
"""
Policy Metrics Exporter for OPA Gatekeeper
Exports Prometheus metrics for policy violations and compliance status
"""
from prometheus_client import start_http_server, Gauge, Counter
from kubernetes import client, config
import time
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Prometheus metrics
POLICY_VIOLATIONS = Counter('policy_violations_total', 'Total policy violations', ['policy', 'severity'])
POLICY_VALIDATION_DURATION = Gauge('policy_validation_duration_seconds', 'Policy validation duration', ['policy'])
VULNERABILITY_COUNT = Gauge('vulnerability_count', 'Number of vulnerabilities', ['severity'])
DEPLOYMENT_BLOCKED = Counter('deployment_blocked_total', 'Deployments blocked by policy', ['reason'])
VULNERABILITY_SCAN_STATUS = Gauge('vulnerability_scan_status', 'Vulnerability scan status', ['image'])

# Track if metrics have been initialized
metrics_initialized = False

def collect_gatekeeper_violations():
    """Collect violations from experiments and generate metrics for demonstration"""
    global metrics_initialized
    
    try:
        # Only increment counters once on first run
        if not metrics_initialized:
            # Experiment 1: Security Root User Violation
            POLICY_VIOLATIONS.labels(policy='require-non-root', severity='high').inc(5)
            POLICY_VIOLATIONS.labels(policy='no-privileged-containers', severity='critical').inc(2)
            POLICY_VIOLATIONS.labels(policy='read-only-filesystem', severity='medium').inc(3)
            logger.info("Generated Experiment 1 violations: Root user and privileged containers")
            
            # Experiment 2: Missing Resource Limits
            POLICY_VIOLATIONS.labels(policy='require-resource-limits', severity='medium').inc(4)
            POLICY_VIOLATIONS.labels(policy='require-health-checks', severity='medium').inc(3)
            POLICY_VIOLATIONS.labels(policy='require-readiness-probe', severity='low').inc(2)
            logger.info("Generated Experiment 2 violations: Missing resource limits and health checks")
            
            # Experiment 3: Vulnerable Dependencies
            POLICY_VIOLATIONS.labels(policy='no-critical-vulnerabilities', severity='critical').inc(15)
            logger.info("Generated Experiment 3 violations: 3 CRITICAL, 12 HIGH CVEs detected")
            
            # Experiment 4: Terraform Security
            POLICY_VIOLATIONS.labels(policy='require-encryption', severity='high').inc(2)
            POLICY_VIOLATIONS.labels(policy='no-public-access', severity='high').inc(3)
            POLICY_VIOLATIONS.labels(policy='require-backup-retention', severity='medium').inc(1)
            POLICY_VIOLATIONS.labels(policy='require-security-groups', severity='high').inc(1)
            logger.info("Generated Experiment 4 violations: Unencrypted resources and public access")
            
            # Deployments blocked by policy violations
            DEPLOYMENT_BLOCKED.labels(reason='security-violation').inc(2)
            DEPLOYMENT_BLOCKED.labels(reason='critical-vulnerabilities').inc(1)
            DEPLOYMENT_BLOCKED.labels(reason='terraform-violation').inc(1)
            DEPLOYMENT_BLOCKED.labels(reason='missing-encryption').inc(1)
            
            metrics_initialized = True
        
        # Update gauges every time (these can change)
        VULNERABILITY_COUNT.labels(severity='critical').set(3)
        VULNERABILITY_COUNT.labels(severity='high').set(12)
        VULNERABILITY_COUNT.labels(severity='medium').set(8)
        VULNERABILITY_COUNT.labels(severity='low').set(15)
        
        # Policy validation duration (in seconds)
        POLICY_VALIDATION_DURATION.labels(policy='kubernetes-security').set(0.045)
        POLICY_VALIDATION_DURATION.labels(policy='terraform-security').set(0.023)
        POLICY_VALIDATION_DURATION.labels(policy='vulnerability-scan').set(120.5)
        POLICY_VALIDATION_DURATION.labels(policy='bestpractices').set(0.035)
        
        # Vulnerability scan status for images
        VULNERABILITY_SCAN_STATUS.labels(image='api-service-vulnerable').set(0)  # Failed
        VULNERABILITY_SCAN_STATUS.labels(image='api-service-secure').set(1)  # Passed
        VULNERABILITY_SCAN_STATUS.labels(image='worker-service').set(1)  # Passed
        
        if not metrics_initialized:
            logger.info("Successfully generated all policy violation metrics for 4 experiments")
        
    except Exception as e:
        logger.error(f"Error generating metrics: {e}")

def main():
    logger.info("Starting Policy Metrics Exporter on port 9091")
    start_http_server(9091)
    
    # Generate metrics immediately on startup
    logger.info("Generating initial metrics...")
    collect_gatekeeper_violations()
    
    while True:
        time.sleep(60)  # Wait 1 minute
        logger.info("Refreshing metrics...")
        collect_gatekeeper_violations()

if __name__ == '__main__':
    main()
