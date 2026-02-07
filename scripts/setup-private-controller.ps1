#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Sets up a private Nexus Secret Controller repository.

.DESCRIPTION
    This script automates the creation of a private repository that will act as the
    distribution center for your Nexus Mods secrets. It copies only the necessary
    distribution workflow and sets up the remote.

.EXAMPLE
    ./setup-private-controller.ps1 -RepoName "my-nexus-secrets"
#>

param (
    [Parameter(Mandatory=$false)]
    [string]$RepoName = "Nexus-Secrets",

    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

# 1. Check for gh CLI
if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI (gh) is required but not found. Please install it from https://cli.github.com/"
    exit 1
}

# 2. Check for git
if (!(Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git is required but not found."
    exit 1
}

$currentDir = Get-Location
$localControllerDir = Join-Path $currentDir "controller"

# Auto-detect if this is an update
$IsUpdate = Test-Path $localControllerDir -PathType Container

if ($DryRun) {
    Write-Host "[DRY RUN] Mode enabled. No changes will be made."
    if ($IsUpdate) {
        Push-Location $localControllerDir
        $remoteUrl = git remote get-url origin 2>$null
        Pop-Location

        Write-Host "[DRY RUN] Target: UPDATE existing local controller at '$localControllerDir'"
        Write-Host "[DRY RUN] Remote: $remoteUrl"
        Write-Host "[DRY RUN] Commands that would run:"
        Write-Host "  - Copy-Item .github/templates/distribute-secrets.yml -> $localControllerDir\.github\workflows\ (Force)"
        Write-Host "  - Copy-Item .github/actions/* -> $localControllerDir\.github\actions\ (Recurse, Force)"
        Write-Host "  - Copy-Item scripts/*.ps1 -> $localControllerDir\scripts\ (Force)"
        Write-Host "  - git add ."
        Write-Host "  - git commit -m 'chore: update controller logic from upstream'"
        Write-Host "  - git push origin main"
    } else {
        $currentUser = "YOUR_USERNAME"
        try { $currentUser = gh api user --jq .login } catch {}

        Write-Host "[DRY RUN] Target: CREATE new private repository on GitHub"
        Write-Host "[DRY RUN] Local Dir: $localControllerDir"
        Write-Host "[DRY RUN] Commands that would run:"
        Write-Host "  - mkdir $localControllerDir"
        Write-Host "  - git init"
        Write-Host "  - Copy-Item .github/templates/distribute-secrets.yml -> .github/workflows/"
        Write-Host "  - Copy-Item .github/actions/* -> .github/actions/"
        Write-Host "  - Copy-Item scripts/*.ps1 -> scripts/"
        Write-Host "  - git add ."
        Write-Host "  - git commit -m 'chore: initial setup of private nexus secret controller'"
        Write-Host "  - gh repo create $RepoName --private --source=. --remote=origin --push"
        Write-Host "`n[DRY RUN] Expected URL: https://github.com/$currentUser/$RepoName"
    }
    exit 0
}

if ($IsUpdate) {
    Write-Host "[INFO] Updating existing controller in: $localControllerDir"
    Push-Location $localControllerDir

    # Refresh content
    Copy-Item -Path (Join-Path $currentDir ".github/templates/distribute-secrets.yml") -Destination ".github/workflows/" -Force
    Copy-Item -Path (Join-Path $currentDir ".github/workflows/validate-access.yml") -Destination ".github/workflows/" -Force
    Copy-Item -Path (Join-Path $currentDir ".github/actions/*") -Destination ".github/actions/" -Recurse -Force

    # Scripts
    if (!(Test-Path "scripts")) { New-Item -ItemType Directory -Path "scripts" | Out-Null }
    Copy-Item -Path (Join-Path $currentDir "scripts/*.ps1") -Destination "scripts/" -Force

    git add .
    git commit -m "chore: update controller logic from upstream"
    git push origin main

    Write-Host "[SUCCESS] Controller updated successfully!"
    Pop-Location
    exit 0
}

Write-Host "[INFO] Initializing new controller in: $localControllerDir"
New-Item -ItemType Directory -Path $localControllerDir | Out-Null
Push-Location $localControllerDir
git init -b main | Out-Null

# 4. Create necessary structure
New-Item -ItemType Directory -Path ".github/workflows" | Out-Null
New-Item -ItemType Directory -Path ".github/actions" | Out-Null
New-Item -ItemType Directory -Path "scripts" | Out-Null

# 5. Copy files from current repo
Write-Host "[INFO] Copying distribution workflows and actions..."
Copy-Item -Path (Join-Path $currentDir ".github/templates/distribute-secrets.yml") -Destination ".github/workflows/"
Copy-Item -Path (Join-Path $currentDir ".github/workflows/validate-access.yml") -Destination ".github/workflows/"
Copy-Item -Path (Join-Path $currentDir ".github/actions/*") -Destination ".github/actions/" -Recurse
Copy-Item -Path (Join-Path $currentDir "scripts/*.ps1") -Destination "scripts/"
Copy-Item -Path (Join-Path $currentDir ".gitignore") -Destination "."

# 6. Create a minimal README for the private repo
$readmeContent = @"
# Nexus Secret Controller (Private)

This is a private repository used to manage and distribute Nexus Mods secrets.

## Standard Operation
- The ``distribute-secrets`` workflow runs every 5 days to refresh and push cookies.
- Do not make this repository public.

## Upstream
This controller was initialized from [alandtse/nexus-workflows](https://github.com/alandtse/nexus-workflows).
"@
$readmeContent | Out-File -FilePath "README.md" -Encoding utf8

# 7. Initial commit
git add .
git commit -m "chore: initial setup of private nexus secret controller" | Out-Null

# 8. Create GitHub repo
Write-Host "[INFO] Creating private repository on GitHub: $RepoName"
gh repo create $RepoName --private --source=. --remote=origin --push

if ($LASTEXITCODE -eq 0) {
    $repoUrl = gh repo view --json url --jq .url
    Write-Host "`n[SUCCESS] Private controller created successfully!"
    Write-Host "`n[NEXT] Now add your secrets to the new repository at:"
    Write-Host "  $repoUrl/settings/secrets/actions"
} else {
    Write-Error "Failed to create GitHub repository."
}

Pop-Location
exit 0
