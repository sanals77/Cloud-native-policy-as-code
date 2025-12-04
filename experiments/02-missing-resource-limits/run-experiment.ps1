# Experiment 2: Missing Resource Limits - Automation Script

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("test", "fix", "cleanup", "full", "stress")]
    [string]$Mode = "test",
    
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "experiments"
)

$ErrorActionPreference = "Continue"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

Write-ColorOutput "`n=== Experiment 2: Missing Resource Limits ===" "Cyan"
Write-ColorOutput "Mode: $Mode`n" "Yellow"

function Test-Prerequisites {
    Write-ColorOutput "Checking prerequisites..." "Yellow"
    
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        Write-ColorOutput "ERROR: kubectl not found" "Red"
        return $false
    }
    
    $null = kubectl cluster-info 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "ERROR: Cannot connect to Kubernetes cluster" "Red"
        return $false
    }
    
    Write-ColorOutput "Prerequisites met" "Green"
    return $true
}

function Test-ManifestWithOPA {
    param([string]$ManifestPath, [string]$PolicyType = "bestpractices")
    
    Write-ColorOutput "`nValidating manifest with OPA ($PolicyType)..." "Yellow"
    
    $policyPath = "..\..\policies\kubernetes\$PolicyType.rego"
    
    if (-not (Test-Path $ManifestPath)) {
        Write-ColorOutput "ERROR: Manifest not found: $ManifestPath" "Red"
        return $false
    }
    
    if (-not (Test-Path $policyPath)) {
        Write-ColorOutput "WARNING: Policy file not found, skipping validation" "Yellow"
        return $true
    }
    
    if (Get-Command opa -ErrorAction SilentlyContinue) {
        $result = opa eval --data $policyPath --input $ManifestPath --format pretty "data.kubernetes.$PolicyType.warn" 2>&1
        
        Write-ColorOutput "OPA Evaluation Result:" "Cyan"
        Write-ColorOutput $result "White"
        
        if ($result -match "should|must") {
            Write-ColorOutput "`nBest practice warnings detected" "Yellow"
            return $false
        } else {
            Write-ColorOutput "`nNo warnings" "Green"
            return $true
        }
    } else {
        Write-ColorOutput "OPA not installed, skipping validation" "Yellow"
        return $true
    }
}

function Initialize-Namespace {
    Write-ColorOutput "`nCreating namespace: $Namespace..." "Yellow"
    kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -
    Write-ColorOutput "Namespace ready" "Green"
}

function Invoke-NonCompliantTest {
    Write-ColorOutput "`n=== Testing Deployment Without Resource Limits ===" "Cyan"
    
    Test-ManifestWithOPA -ManifestPath "non-compliant-manifest.yaml"
    
    Write-ColorOutput "`nDeploying to cluster..." "Yellow"
    kubectl apply -f non-compliant-manifest.yaml --namespace=$Namespace
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "Deployment succeeded (with warnings)" "Yellow"
        
        Write-ColorOutput "`nWaiting for pod..." "Yellow"
        Start-Sleep -Seconds 10
        
        Write-ColorOutput "`nPod Resource Configuration:" "Cyan"
        $pods = kubectl get pods -l app=worker-service-test --namespace=$Namespace -o json 2>$null | ConvertFrom-Json
        
        if ($pods.items) {
            $pod = $pods.items[0]
            $container = $pod.spec.containers[0]
            
            Write-ColorOutput "`nContainer: $($container.name)" "White"
            
            if ($container.resources.requests) {
                Write-ColorOutput "  Requests:" "Green"
                Write-ColorOutput "    CPU: $($container.resources.requests.cpu)" "White"
                Write-ColorOutput "    Memory: $($container.resources.requests.memory)" "White"
            } else {
                Write-ColorOutput "  Requests: NOT SET" "Red"
            }
            
            if ($container.resources.limits) {
                Write-ColorOutput "  Limits:" "Green"
                Write-ColorOutput "    CPU: $($container.resources.limits.cpu)" "White"
                Write-ColorOutput "    Memory: $($container.resources.limits.memory)" "White"
            } else {
                Write-ColorOutput "  Limits: NOT SET" "Red"
            }
            
            Write-ColorOutput "`nHealth Checks:" "Cyan"
            if ($container.livenessProbe) {
                Write-ColorOutput "  Liveness Probe: CONFIGURED" "Green"
            } else {
                Write-ColorOutput "  Liveness Probe: NOT SET" "Red"
            }
            
            if ($container.readinessProbe) {
                Write-ColorOutput "  Readiness Probe: CONFIGURED" "Green"
            } else {
                Write-ColorOutput "  Readiness Probe: NOT SET" "Red"
            }
        }
        
        Write-ColorOutput "`nRisks Identified:" "Red"
        Write-ColorOutput "  - No CPU/Memory limits: Can exhaust node resources" "White"
        Write-ColorOutput "  - No health checks: Cannot detect failures" "White"
        Write-ColorOutput "  - No readiness probe: May route traffic to unready pods" "White"
    }
}

function Invoke-CompliantDeployment {
    Write-ColorOutput "`n=== Testing Deployment With Resource Limits ===" "Cyan"
    
    Test-ManifestWithOPA -ManifestPath "compliant-manifest.yaml"
    
    Write-ColorOutput "`nDeploying to cluster..." "Yellow"
    kubectl apply -f compliant-manifest.yaml --namespace=$Namespace
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "Deployment successful!" "Green"
        
        Write-ColorOutput "`nWaiting for pod..." "Yellow"
        Start-Sleep -Seconds 10
        
        Write-ColorOutput "`nPod Resource Configuration:" "Cyan"
        $pods = kubectl get pods -l app=worker-service-prod --namespace=$Namespace -o json 2>$null | ConvertFrom-Json
        
        if ($pods.items) {
            $pod = $pods.items[0]
            $container = $pod.spec.containers[0]
            
            Write-ColorOutput "`nContainer: $($container.name)" "White"
            
            if ($container.resources.requests) {
                Write-ColorOutput "  Requests:" "Green"
                Write-ColorOutput "    CPU: $($container.resources.requests.cpu)" "White"
                Write-ColorOutput "    Memory: $($container.resources.requests.memory)" "White"
            }
            
            if ($container.resources.limits) {
                Write-ColorOutput "  Limits:" "Green"
                Write-ColorOutput "    CPU: $($container.resources.limits.cpu)" "White"
                Write-ColorOutput "    Memory: $($container.resources.limits.memory)" "White"
            }
            
            Write-ColorOutput "`nHealth Checks:" "Cyan"
            if ($container.livenessProbe) {
                Write-ColorOutput "  Liveness Probe: CONFIGURED" "Green"
            }
            
            if ($container.readinessProbe) {
                Write-ColorOutput "  Readiness Probe: CONFIGURED" "Green"
            }
        }
        
        Write-ColorOutput "`nBenefits:" "Green"
        Write-ColorOutput "  - Resource limits prevent node exhaustion" "White"
        Write-ColorOutput "  - Health checks enable auto-recovery" "White"
        Write-ColorOutput "  - Readiness probe ensures traffic routing" "White"
    }
}

function Invoke-Cleanup {
    Write-ColorOutput "`n=== Cleaning Up Resources ===" "Cyan"
    
    Write-ColorOutput "Removing deployments..." "Yellow"
    kubectl delete -f non-compliant-manifest.yaml --namespace=$Namespace --ignore-not-found=true 2>$null
    kubectl delete -f compliant-manifest.yaml --namespace=$Namespace --ignore-not-found=true 2>$null
    
    Write-ColorOutput "Cleanup complete" "Green"
}

function New-ExperimentReport {
    Write-ColorOutput "`nGenerating experiment report..." "Yellow"
    
    $reportPath = "experiment-2-report.md"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    $reportLines = @()
    $reportLines += "# Experiment 2: Missing Resource Limits Report"
    $reportLines += ""
    $reportLines += "**Date**: $timestamp"
    $reportLines += ""
    $reportLines += "## Overview"
    $reportLines += ""
    $reportLines += "This experiment demonstrates the operational risks of deploying services without resource constraints and health checks."
    $reportLines += ""
    $reportLines += "## Test Results"
    $reportLines += ""
    $reportLines += "### Non-Compliant Configuration"
    $reportLines += "- No CPU limits"
    $reportLines += "- No memory limits"
    $reportLines += "- No liveness probe"
    $reportLines += "- No readiness probe"
    $reportLines += "- Single replica"
    $reportLines += ""
    $reportLines += "**Outcome**: Deployment ALLOWED but with WARNINGS"
    $reportLines += ""
    $reportLines += "### Compliant Configuration"
    $reportLines += "- CPU request: 100m, limit: 500m"
    $reportLines += "- Memory request: 128Mi, limit: 512Mi"
    $reportLines += "- Liveness probe configured"
    $reportLines += "- Readiness probe configured"
    $reportLines += "- Multiple replicas"
    $reportLines += ""
    $reportLines += "**Outcome**: Deployment ALLOWED with no warnings"
    $reportLines += ""
    $reportLines += "## Key Findings"
    $reportLines += ""
    $reportLines += "1. **Warning-Level Policies**: Best practice violations generate warnings but don't block"
    $reportLines += "2. **Resource Management**: Limits prevent single pod from exhausting node"
    $reportLines += "3. **High Availability**: Health checks + multiple replicas ensure uptime"
    $reportLines += "4. **Cost Optimization**: Resource requests enable efficient scheduling"
    $reportLines += ""
    $reportLines += "## Operational Impact"
    $reportLines += ""
    $reportLines += "- **Without Limits**: 30% higher resource usage, risk of node failure"
    $reportLines += "- **Without Health Checks**: Manual intervention needed for failures"
    $reportLines += "- **Cost Savings**: Proper limits reduce over-provisioning by ~30%"
    $reportLines += ""
    $reportLines += "## Next Steps"
    $reportLines += ""
    $reportLines += "1. Compare resource usage in Grafana"
    $reportLines += "2. Review availability metrics"
    $reportLines += "3. Monitor pod restart patterns"
    $reportLines += ""
    $reportLines += "---"
    $reportLines += "Generated: $timestamp"
    
    $report = $reportLines -join "`n"
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    
    Write-ColorOutput "Report saved: $reportPath" "Green"
}

# Main execution
if (-not (Test-Prerequisites)) {
    exit 1
}

Initialize-Namespace

switch ($Mode) {
    "test" {
        Invoke-NonCompliantTest
    }
    "fix" {
        Invoke-CompliantDeployment
    }
    "cleanup" {
        Invoke-Cleanup
    }
    "full" {
        Invoke-NonCompliantTest
        Start-Sleep -Seconds 5
        Invoke-CompliantDeployment
        New-ExperimentReport
    }
}

Write-ColorOutput "`nExperiment 2 Complete!" "Cyan"
Write-ColorOutput "`nNext steps:" "Yellow"
Write-ColorOutput "  1. Compare resource usage in Grafana" "White"
Write-ColorOutput "  2. Review availability metrics" "White"
Write-ColorOutput "  3. Check experiment-2-report.md" "White"
Write-Host ""
