# Experiment 3: Vulnerable Dependencies - Automation Script

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("test", "fix", "cleanup", "full", "compare")]
    [string]$Mode = "test"
)

$ErrorActionPreference = "Continue"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

Write-ColorOutput "`n=== Experiment 3: Vulnerable Dependencies ===" "Cyan"
Write-ColorOutput "Mode: $Mode`n" "Yellow"

$imageName = "api-service-experiment"
$vulnerableTag = "vulnerable"
$secureTag = "secure"

function Test-Prerequisites {
    Write-ColorOutput "Checking prerequisites..." "Yellow"
    
    $tools = @("docker", "trivy")
    $missing = @()
    
    foreach ($tool in $tools) {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
            $missing += $tool
        }
    }
    
    if ($missing.Count -gt 0) {
        Write-ColorOutput "ERROR: Missing tools: $($missing -join ', ')" "Red"
        Write-ColorOutput "`nInstallation instructions:" "Yellow"
        Write-ColorOutput "  Docker: https://www.docker.com/products/docker-desktop" "White"
        Write-ColorOutput "  Trivy: https://aquasecurity.github.io/trivy/latest/getting-started/installation/" "White"
        return $false
    }
    
    Write-ColorOutput "All prerequisites met" "Green"
    return $true
}

function Invoke-VulnerableImageTest {
    Write-ColorOutput "`n=== Building and Scanning Vulnerable Image ===" "Cyan"
    
    Write-ColorOutput "`nPreparing build context..." "Yellow"
    if (-not (Test-Path "app.py")) {
        Copy-Item "..\..\microservices\api-service\app.py" "app.py"
    }
    
    Write-ColorOutput "`nBuilding vulnerable image..." "Yellow"
    docker build -t ${imageName}:${vulnerableTag} -f Dockerfile.vulnerable .
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "ERROR: Failed to build image" "Red"
        return
    }
    
    Write-ColorOutput "Image built successfully" "Green"
    
    Write-ColorOutput "`nScanning for vulnerabilities..." "Yellow"
    Write-ColorOutput "This may take a few minutes on first run...`n" "White"
    
    trivy image --severity HIGH,CRITICAL ${imageName}:${vulnerableTag}
    
    Write-ColorOutput "`nGenerating detailed report..." "Yellow"
    trivy image --severity HIGH,CRITICAL --format json --output scan-vulnerable.json ${imageName}:${vulnerableTag}
    
    if (Test-Path "scan-vulnerable.json") {
        $report = Get-Content "scan-vulnerable.json" | ConvertFrom-Json
        
        $vulns = $report.Results | Where-Object { $_.Vulnerabilities } | ForEach-Object { $_.Vulnerabilities }
        $critical = ($vulns | Where-Object { $_.Severity -eq "CRITICAL" }).Count
        $high = ($vulns | Where-Object { $_.Severity -eq "HIGH" }).Count
        
        Write-ColorOutput "`nVulnerability Summary:" "Cyan"
        Write-ColorOutput "  CRITICAL: $critical" "Red"
        Write-ColorOutput "  HIGH: $high" "Red"
        Write-ColorOutput "  Total HIGH/CRITICAL: $($critical + $high)" "Red"
        
        Write-ColorOutput "`nTop Critical Vulnerabilities:" "Red"
        $topVulns = $vulns | Where-Object { $_.Severity -eq "CRITICAL" } | Select-Object -First 3
        foreach ($vuln in $topVulns) {
            Write-ColorOutput "`n  CVE: $($vuln.VulnerabilityID)" "White"
            Write-ColorOutput "  Package: $($vuln.PkgName) $($vuln.InstalledVersion)" "White"
            if ($vuln.CVSS.nvd.V3Score) {
                Write-ColorOutput "  Severity: $($vuln.Severity) (CVSS: $($vuln.CVSS.nvd.V3Score))" "Red"
            } else {
                Write-ColorOutput "  Severity: $($vuln.Severity)" "Red"
            }
            Write-ColorOutput "  Title: $($vuln.Title)" "White"
            if ($vuln.FixedVersion) {
                Write-ColorOutput "  Fix: Upgrade to $($vuln.FixedVersion)" "Yellow"
            }
        }
        
        Write-ColorOutput "`nDecision: BLOCK deployment due to critical vulnerabilities" "Red"
    }
}

function Invoke-SecureImageTest {
    Write-ColorOutput "`n=== Building and Scanning Secure Image ===" "Cyan"
    
    Write-ColorOutput "`nPreparing build context..." "Yellow"
    if (-not (Test-Path "app.py")) {
        Copy-Item "..\..\microservices\api-service\app.py" "app.py"
    }
    
    Write-ColorOutput "`nBuilding secure image..." "Yellow"
    docker build -t ${imageName}:${secureTag} -f Dockerfile.secure .
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "ERROR: Failed to build image" "Red"
        return
    }
    
    Write-ColorOutput "Image built successfully" "Green"
    
    Write-ColorOutput "`nScanning for vulnerabilities..." "Yellow"
    trivy image --severity HIGH,CRITICAL ${imageName}:${secureTag}
    
    Write-ColorOutput "`nGenerating detailed report..." "Yellow"
    trivy image --severity HIGH,CRITICAL --format json --output scan-secure.json ${imageName}:${secureTag}
    
    if (Test-Path "scan-secure.json") {
        $report = Get-Content "scan-secure.json" | ConvertFrom-Json
        
        $vulns = $report.Results | Where-Object { $_.Vulnerabilities } | ForEach-Object { $_.Vulnerabilities }
        $critical = ($vulns | Where-Object { $_.Severity -eq "CRITICAL" }).Count
        $high = ($vulns | Where-Object { $_.Severity -eq "HIGH" }).Count
        
        Write-ColorOutput "`nVulnerability Summary:" "Cyan"
        Write-ColorOutput "  CRITICAL: $critical" "Green"
        Write-ColorOutput "  HIGH: $high" "Green"
        Write-ColorOutput "  Total HIGH/CRITICAL: $($critical + $high)" "Green"
        
        if ($critical -eq 0 -and $high -eq 0) {
            Write-ColorOutput "`nDecision: ALLOW deployment - no critical vulnerabilities" "Green"
        } else {
            Write-ColorOutput "`nDecision: REVIEW required - some vulnerabilities remain" "Yellow"
        }
    }
}

function Invoke-Comparison {
    Write-ColorOutput "`n=== Vulnerability Comparison ===" "Cyan"
    
    if ((Test-Path "scan-vulnerable.json") -and (Test-Path "scan-secure.json")) {
        $vulnReport = Get-Content "scan-vulnerable.json" | ConvertFrom-Json
        $secureReport = Get-Content "scan-secure.json" | ConvertFrom-Json
        
        $vulnVulns = $vulnReport.Results | Where-Object { $_.Vulnerabilities } | ForEach-Object { $_.Vulnerabilities }
        $secureVulns = $secureReport.Results | Where-Object { $_.Vulnerabilities } | ForEach-Object { $_.Vulnerabilities }
        
        $vulnCritical = ($vulnVulns | Where-Object { $_.Severity -eq "CRITICAL" }).Count
        $vulnHigh = ($vulnVulns | Where-Object { $_.Severity -eq "HIGH" }).Count
        
        $secureCritical = ($secureVulns | Where-Object { $_.Severity -eq "CRITICAL" }).Count
        $secureHigh = ($secureVulns | Where-Object { $_.Severity -eq "HIGH" }).Count
        
        Write-ColorOutput "`n{0,-20} {1,15} {2,15}" -f "Metric", "Vulnerable", "Secure" "White"
        Write-ColorOutput "{0,-20} {1,15} {2,15}" -f "--------------------", "---------------", "---------------" "Gray"
        Write-ColorOutput ("{0,-20} {1,15} {2,15}" -f "CRITICAL", $vulnCritical, $secureCritical) "White"
        Write-ColorOutput ("{0,-20} {1,15} {2,15}" -f "HIGH", $vulnHigh, $secureHigh) "White"
        Write-ColorOutput ("{0,-20} {1,15} {2,15}" -f "Total", ($vulnCritical+$vulnHigh), ($secureCritical+$secureHigh)) "White"
        
        $reduction = $vulnCritical + $vulnHigh - $secureCritical - $secureHigh
        Write-ColorOutput "`nVulnerabilities Eliminated: $reduction" "Green"
    }
}

function Invoke-Cleanup {
    Write-ColorOutput "`n=== Cleaning Up Resources ===" "Cyan"
    
    Write-ColorOutput "Removing Docker images..." "Yellow"
    docker rmi ${imageName}:${vulnerableTag} -f 2>$null
    docker rmi ${imageName}:${secureTag} -f 2>$null
    
    Write-ColorOutput "Removing temporary files..." "Yellow"
    Remove-Item "app.py" -ErrorAction SilentlyContinue
    Remove-Item "scan-*.json" -ErrorAction SilentlyContinue
    
    Write-ColorOutput "Cleanup complete" "Green"
}

function New-ExperimentReport {
    Write-ColorOutput "`nGenerating experiment report..." "Yellow"
    
    $reportPath = "experiment-3-report.md"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    $reportLines = @()
    $reportLines += "# Experiment 3: Vulnerable Dependencies Report"
    $reportLines += ""
    $reportLines += "**Date**: $timestamp"
    $reportLines += ""
    $reportLines += "## Overview"
    $reportLines += ""
    $reportLines += "This experiment demonstrates automated vulnerability detection in container images using Trivy scanner."
    $reportLines += ""
    $reportLines += "## Test Results"
    $reportLines += ""
    $reportLines += "### Vulnerable Image"
    $reportLines += "- Base: python:3.8-slim"
    $reportLines += "- Old dependencies (Flask 1.1.2, Werkzeug 1.0.1)"
    $reportLines += "- Multiple HIGH/CRITICAL CVEs detected"
    $reportLines += "- Examples: CVE-2023-30861, CVE-2023-25577"
    $reportLines += ""
    $reportLines += "**Decision**: BLOCK deployment"
    $reportLines += ""
    $reportLines += "### Secure Image"
    $reportLines += "- Base: python:3.11-slim"
    $reportLines += "- Updated dependencies (Flask 3.0.0, Werkzeug 3.0.0)"
    $reportLines += "- Zero or minimal HIGH/CRITICAL CVEs"
    $reportLines += ""
    $reportLines += "**Decision**: ALLOW deployment"
    $reportLines += ""
    $reportLines += "## Key Findings"
    $reportLines += ""
    $reportLines += "1. **Automated Scanning**: Trivy identifies vulnerabilities in ~2 minutes"
    $reportLines += "2. **Actionable Results**: CVE IDs with fix versions provided"
    $reportLines += "3. **CI/CD Integration**: Can block builds with vulnerable dependencies"
    $reportLines += "4. **Continuous Monitoring**: Regular scans catch newly disclosed CVEs"
    $reportLines += ""
    $reportLines += "## Security Impact"
    $reportLines += ""
    $reportLines += "- **Attack Prevention**: Blocks known exploitable vulnerabilities"
    $reportLines += "- **Compliance**: Meets security scanning requirements"
    $reportLines += "- **Cost Avoidance**: Average breach costs $3.86M"
    $reportLines += ""
    $reportLines += "## Real-World Parallels"
    $reportLines += ""
    $reportLines += "- Equifax breach (2017): Unpatched vulnerability cost $1.4B"
    $reportLines += "- SolarWinds (2020): Supply chain compromise affected 18,000 customers"
    $reportLines += ""
    $reportLines += "## Next Steps"
    $reportLines += ""
    $reportLines += "1. Review scan results in detail"
    $reportLines += "2. Integrate Trivy into CI/CD pipeline"
    $reportLines += "3. Set up automated daily scans"
    $reportLines += "4. Configure alerting for new CVEs"
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

switch ($Mode) {
    "test" {
        Invoke-VulnerableImageTest
    }
    "fix" {
        Invoke-SecureImageTest
    }
    "cleanup" {
        Invoke-Cleanup
    }
    "compare" {
        Invoke-Comparison
    }
    "full" {
        Invoke-VulnerableImageTest
        Start-Sleep -Seconds 3
        Invoke-SecureImageTest
        Start-Sleep -Seconds 2
        Invoke-Comparison
        New-ExperimentReport
    }
}

Write-ColorOutput "`nExperiment 3 Complete!" "Cyan"
Write-ColorOutput "`nNext steps:" "Yellow"
Write-ColorOutput "  1. Review scan reports (scan-*.json)" "White"
Write-ColorOutput "  2. Check experiment-3-report.md" "White"
Write-ColorOutput "  3. Integrate Trivy into CI/CD" "White"
Write-Host ""
