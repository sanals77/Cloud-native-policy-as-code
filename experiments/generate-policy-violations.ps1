# Script to generate policy violations and push metrics to Prometheus/Grafana
# This simulates the CI/CD pipeline detecting policy violations

param(
    [Parameter(Mandatory=$false)]
    [string]$PrometheusUrl = "http://localhost:9091/metrics"
)

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

Write-ColorOutput "`n=== Policy Violation Metrics Generator ===" "Cyan"
Write-ColorOutput "This script simulates policy violations for Grafana visualization`n" "Yellow"

# Simulate policy violations from experiments
$violations = @(
    @{
        policy = "require-non-root"
        type = "kubernetes"
        severity = "high"
        experiment = "01-security-root-user"
        count = 5
    },
    @{
        policy = "no-privileged-containers"
        type = "kubernetes"
        severity = "critical"
        experiment = "01-security-root-user"
        count = 2
    },
    @{
        policy = "require-resource-limits"
        type = "kubernetes"
        severity = "medium"
        experiment = "02-missing-resource-limits"
        count = 3
    },
    @{
        policy = "require-health-checks"
        type = "kubernetes"
        severity = "medium"
        experiment = "02-missing-resource-limits"
        count = 4
    },
    @{
        policy = "no-critical-vulnerabilities"
        type = "container"
        severity = "critical"
        experiment = "03-vulnerable-dependencies"
        count = 15
    },
    @{
        policy = "require-encryption"
        type = "terraform"
        severity = "high"
        experiment = "04-terraform-security"
        count = 2
    },
    @{
        policy = "no-public-access"
        type = "terraform"
        severity = "high"
        experiment = "04-terraform-security"
        count = 3
    }
)

# Generate Prometheus metrics format
$metrics = @()
$metrics += "# HELP policy_violations_total Total number of policy violations detected"
$metrics += "# TYPE policy_violations_total counter"

foreach ($violation in $violations) {
    $labels = "policy=`"$($violation.policy)`",type=`"$($violation.type)`",severity=`"$($violation.severity)`",experiment=`"$($violation.experiment)`""
    $metrics += "policy_violations_total{$labels} $($violation.count)"
}

$metrics += ""
$metrics += "# HELP deployment_blocked_total Number of deployments blocked due to policy violations"
$metrics += "# TYPE deployment_blocked_total counter"
$metrics += "deployment_blocked_total{reason=`"policy-violation`",type=`"kubernetes`"} 2"
$metrics += "deployment_blocked_total{reason=`"critical-vulnerabilities`",type=`"container`"} 1"
$metrics += "deployment_blocked_total{reason=`"security-violation`",type=`"terraform`"} 1"

$metrics += ""
$metrics += "# HELP deployment_success_total Number of successful deployments after fixing violations"
$metrics += "# TYPE deployment_success_total counter"
$metrics += "deployment_success_total{type=`"kubernetes`"} 2"
$metrics += "deployment_success_total{type=`"container`"} 1"
$metrics += "deployment_success_total{type=`"terraform`"} 1"

$metrics += ""
$metrics += "# HELP vulnerability_count Number of vulnerabilities by severity"
$metrics += "# TYPE vulnerability_count gauge"
$metrics += "vulnerability_count{severity=`"critical`",image=`"vulnerable`"} 3"
$metrics += "vulnerability_count{severity=`"high`",image=`"vulnerable`"} 12"
$metrics += "vulnerability_count{severity=`"critical`",image=`"secure`"} 0"
$metrics += "vulnerability_count{severity=`"high`",image=`"secure`"} 0"

$metrics += ""
$metrics += "# HELP policy_validation_duration_seconds Time taken to validate policies"
$metrics += "# TYPE policy_validation_duration_seconds histogram"
$metrics += "policy_validation_duration_seconds{policy=`"kubernetes-security`"} 0.045"
$metrics += "policy_validation_duration_seconds{policy=`"terraform-security`"} 0.023"
$metrics += "policy_validation_duration_seconds{policy=`"vulnerability-scan`"} 120.5"

Write-ColorOutput "Generated Metrics:" "Cyan"
Write-ColorOutput ($metrics -join "`n") "White"

# Save to file
$metricsFile = "policy-violations-metrics.txt"
$metrics -join "`n" | Out-File -FilePath $metricsFile -Encoding UTF8

Write-ColorOutput "`nMetrics saved to: $metricsFile" "Green"

# Instructions for pushing to Prometheus
Write-ColorOutput "`n=== How to Push Metrics to Prometheus ===" "Cyan"
Write-ColorOutput ""
Write-ColorOutput "Option 1: Use the policy-metrics-exporter (recommended)" "Yellow"
Write-ColorOutput "  The exporter at http://localhost:9091/metrics should serve these" "White"
Write-ColorOutput ""
Write-ColorOutput "Option 2: Manually query in Prometheus" "Yellow"
Write-ColorOutput "  1. Open Prometheus: http://localhost:9090" "White"
Write-ColorOutput "  2. Go to Status > Targets" "White"
Write-ColorOutput "  3. Verify 'policy-metrics-exporter' target is UP" "White"
Write-ColorOutput "  4. Query: policy_violations_total" "White"
Write-ColorOutput ""
Write-ColorOutput "Option 3: Port-forward and check metrics endpoint" "Yellow"
Write-ColorOutput "  kubectl port-forward -n monitoring svc/policy-metrics-exporter 9091:9091" "White"
Write-ColorOutput "  curl http://localhost:9091/metrics" "White"
Write-ColorOutput ""

# Try to fetch current metrics from the exporter
Write-ColorOutput "Checking current metrics from exporter..." "Yellow"
try {
    kubectl port-forward -n monitoring svc/policy-metrics-exporter 9091:9091 2>&1 | Out-Null &
    Start-Sleep -Seconds 2
    $response = Invoke-WebRequest -Uri "http://localhost:9091/metrics" -UseBasicParsing -TimeoutSec 5
    Write-ColorOutput "`nCurrent Exporter Metrics:" "Green"
    Write-ColorOutput $response.Content "White"
} catch {
    Write-ColorOutput "Could not fetch metrics from exporter: $_" "Yellow"
    Write-ColorOutput "The exporter may not be exposing metrics yet" "Yellow"
}

Write-ColorOutput "`nNext Steps:" "Cyan"
Write-ColorOutput "1. Update the policy-metrics-exporter.py to generate actual violations" "White"
Write-ColorOutput "2. Restart the exporter pod to pick up changes" "White"
Write-ColorOutput "3. Verify metrics appear in Prometheus queries" "White"
Write-ColorOutput "4. Check Grafana dashboards refresh with data" "White"
Write-Host ""
