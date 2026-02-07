param(
    [string]$ReposJson,
    [string]$Cookie,
    [string]$ApiKey,
    [string]$ExcludeRepos,
    [switch]$DryRun
)

$ErrorActionPreference = "Continue" # Don't stop on single repo failure

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Err {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Success {
    param([string]$Message)
    Write-Host "  [SUCCESS] $Message" -ForegroundColor Green
}

if ([string]::IsNullOrWhiteSpace($ReposJson) -or $ReposJson -eq "[]") {
    Write-Info "No repositories to process."
    exit 0
}

$repos = $ReposJson | ConvertFrom-Json
$excludeList = if ($ExcludeRepos) { $ExcludeRepos.Split(',') | ForEach-Object { $_.Trim() } } else { @() }

Write-Output "----------------------------------------"
if ($DryRun) {
    Write-Output "[TEST] DRY RUN - No secrets will be updated"
} else {
    Write-Output "[INFO] Distributing secrets to $($repos.Count) repositories"
}
Write-Output "----------------------------------------"

$successCount = 0
$failCount = 0

foreach ($repo in $repos) {
    if ($excludeList -contains $repo) {
        Write-Output "[SKIP] $repo (listed in exclusion list)"
        continue
    }

    if ($DryRun) {
        Write-Output "  - Would update: $repo"
        $successCount++
        continue
    }

    Write-Info "Checking: $repo"

    # Check if repo has UNEX_SKIP secret
    try {
        $secrets = gh secret list --repo "$repo" --json name | ConvertFrom-Json
        if ($secrets.name -contains "UNEX_SKIP") {
            Write-Output "[SKIP] $repo (UNEX_SKIP secret detected)"
            continue
        }
    }
    catch {
        Write-Err "Failed to list secrets for $repo. skipping."
        $failCount++
        continue
    }

    Write-Info "Updating: $repo"

    # Update Cookie
    try {
        if (-not [string]::IsNullOrWhiteSpace($Cookie)) {
            $Cookie | gh secret set UNEX_NEXUSMODS_SESSION_COOKIE --repo "$repo"
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Session cookie updated"
            } else {
                throw "gh secret set returned non-zero"
            }
        }
    }
    catch {
        Write-Err "Failed to update cookie on $repo"
        $failCount++
        continue
    }

    # Update API Key
    try {
        if (-not [string]::IsNullOrWhiteSpace($ApiKey)) {
            $ApiKey | gh secret set UNEX_APIKEY --repo "$repo"
            if ($LASTEXITCODE -eq 0) {
                Write-Success "API key updated"
            } else {
                throw "gh secret set returned non-zero"
            }
        }
        $successCount++
    }
    catch {
        Write-Err "Failed to update API key on $repo"
        $failCount++ # Treat partial failure as failure? Or success if cookie worked?
                     # Let's count it as failure for visibility
    }
}

Write-Output "`n[INFO] Summary: $successCount updated, $failCount failed."

if ($failCount -gt 0) {
    exit 1
}
