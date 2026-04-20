param(
    [string]$SearchQueries = "",
    [string]$IncludeRepos = "",
    [string]$ExcludeRepos = "",
    [string]$CurrentRepo = "",
    [string]$Owner = ""
)

# Use Parameter values if provided, otherwise fallback to Environment Variables
# This ensures reliability in CI environments where parameter binding may be inconsistent.
$Owner = if ($Owner) { $Owner } elseif ($env:UNEX_OWNER) { $env:UNEX_OWNER } else { "alandtse" }
$SearchQueries = if ($SearchQueries) { $SearchQueries } elseif ($env:UNEX_SEARCH_QUERIES) { $env:UNEX_SEARCH_QUERIES } else { "UNEX_NEXUSMODS_SESSION_COOKIE,NexusUploader,nexus-workflows" }
$IncludeRepos = if ($IncludeRepos) { $IncludeRepos } else { $env:UNEX_INCLUDE_REPOS }
$ExcludeRepos = if ($ExcludeRepos) { $ExcludeRepos } else { $env:UNEX_EXCLUDE_REPOS }
$CurrentRepo = if ($CurrentRepo) { $CurrentRepo } else { $env:UNEX_CURRENT_REPO }

# 1. CI MOCK: Standalone mock for CI reliability
if ($env:MOCK_GH_RESULT) {
    function gh { return $env:MOCK_GH_RESULT }
}

$ErrorActionPreference = "Stop"
$uniqueRepos = New-Object System.Collections.Hashtable([System.StringComparer]::OrdinalIgnoreCase)

function Write-Info {
    param([string]$Message)
    Write-Host "  - info: $Message"
}

# 2. Manual Inclusions
if (-not [string]::IsNullOrWhiteSpace($IncludeRepos)) {
    $includeList = $IncludeRepos.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    foreach ($repo in $includeList) {
        $uniqueRepos[$repo] = [PSCustomObject]@{
            nameWithOwner = $repo
            source        = "manual"
        }
        Write-Info "Manually included: $repo"
    }
}

# 3. Discovery Loop
if (-not [string]::IsNullOrWhiteSpace($SearchQueries)) {
    $queries = $SearchQueries.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    foreach ($query in $queries) {
        foreach ($forkState in @($false, $true)) {
            $searchTerms = @("path:.github/workflows", $query)
            if ($forkState) {
                $searchTerms += "fork:true"
                Write-Info "Searching for: '$query' (including forks)"
            } else {
                Write-Info "Searching for: '$query' (standard repos)"
            }

            if (-not [string]::IsNullOrWhiteSpace($Owner)) { $searchTerms += "user:$Owner" }

            $ghArgs = @("search", "code") + $searchTerms + @("--json", "repository", "--limit", "100")

            try {
                $searchResults = gh @ghArgs | Out-String
                if ($searchResults) {
                    $results = $searchResults | ConvertFrom-Json
                    foreach ($item in $results) {
                        $repoName = $item.repository.nameWithOwner
                        if ($repoName -and (-not $uniqueRepos.ContainsKey($repoName))) {
                            $uniqueRepos[$repoName] = $item.repository
                            Write-Host "  + Found: $repoName"
                        }
                    }
                }
            }
            catch {
                Write-Warning "Search failed for query '$query': $_"
            }
            Start-Sleep -Seconds 1
        }
    }
}

# 4. Filter and Exclude
$finalRepos = @()
$excludeList = if ($ExcludeRepos) { $ExcludeRepos.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ } } else { @() }

Write-Info "Filtering results..."
foreach ($key in $uniqueRepos.Keys) {
    $repoName = $uniqueRepos[$key].nameWithOwner
    if ($repoName -eq $CurrentRepo) { Write-Host "  - Skipping $repoName (Current Repo)"; continue }
    if ($uniqueRepos[$key].source -eq "manual") {
        $finalRepos += $repoName
        continue
    }
    if ($excludeList -contains $repoName) { Write-Host "  - Skipping $repoName (Excluded)"; continue }
    if ($repoName -match "/nexus-workflows$") { Write-Host "  - Skipping $repoName (Nexus Workflows)"; continue }
    $finalRepos += $repoName
}

# 5. Result Formatting
Write-Info "Found $($finalRepos.Count) repositories."
if ($null -eq $finalRepos -or $finalRepos.Count -eq 0) { "[]" }
else { ConvertTo-Json -InputObject @($finalRepos | Sort-Object -Unique) -Compress }
