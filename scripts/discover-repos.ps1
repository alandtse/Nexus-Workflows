param(
    [string]$SearchQueries = "UNEX_NEXUSMODS_SESSION_COOKIE,NexusUploader,nexus-workflows",
    [string]$IncludeRepos = "",
    [string]$ExcludeRepos = "",
    [string]$CurrentRepo = "",
    [string]$Owner = ""
)

$ErrorActionPreference = "Stop"
$uniqueRepos = @{}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Err {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# 1. Handle Hardcoded Includes
if (-not [string]::IsNullOrWhiteSpace($IncludeRepos)) {
    Write-Info "Processing manual inclusion list..."
    $includes = $IncludeRepos.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    foreach ($repo in $includes) {
        if (-not $uniqueRepos.ContainsKey($repo)) {
            $uniqueRepos[$repo] = @{ nameWithOwner = $repo; source = "manual" }
            Write-Host "  + Added manual repo: $repo"
        }
    }
}

# 2. Handle Search Queries
if (-not [string]::IsNullOrWhiteSpace($SearchQueries)) {
    $queries = $SearchQueries.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($query in $queries) {
        foreach ($forkState in @("true", "default")) {

            # Build the query string
            # We search in .github/workflows
            $searchTerms = @("path:.github/workflows", "$query")

            if ($forkState -eq "true") {
                $searchTerms += "fork:true"
                Write-Info "Searching for: '$query' (including forks)"
            } else {
                Write-Info "Searching for: '$query' (standard repos)"
            }

            if (-not [string]::IsNullOrWhiteSpace($Owner)) {
                $searchTerms += "user:$Owner"
            }

            # Correctly invoke gh with arguments array instead of single string
            $ghArgs = @("search", "code") + $searchTerms + @("--json", "repository", "--limit", "100")

            # Show full command for debugging (approximate)
            Write-Host "  Command: gh search code $searchTerms --json repository --limit 100"

            try {
                # Run gh search using splatting to ensure arguments are passed correctly
                $searchResults = & gh @ghArgs

                if ($searchResults) {
                    $results = $searchResults | ConvertFrom-Json
                    $stepCount = 0
                    foreach ($item in $results) {
                        $repoName = $item.repository.nameWithOwner
                        if (-not $uniqueRepos.ContainsKey($repoName)) {
                            $uniqueRepos[$repoName] = $item.repository
                            Write-Host "  + Found: $repoName"
                            $stepCount++
                        }
                    }
                    Write-Host "  > Found $stepCount new repositories in this step."
                } else {
                    Write-Host "  > No results found."
                }
            }
            catch {
                Write-Warning "Search failed for query '$query' (fork:$forkState): $_"
            }
        }
    }
}

# 3. Filter and Exclude
$finalRepos = @()
$excludeList = if ($ExcludeRepos) { $ExcludeRepos.Split(',') | ForEach-Object { $_.Trim() } } else { @() }

Write-Info "Filtering results..."

foreach ($key in $uniqueRepos.Keys) {
    $repoName = $uniqueRepos[$key].nameWithOwner

    # Exclude current repo to avoid self-update loops if running in one of them
    if ($repoName -eq $CurrentRepo) {
        Write-Host "  - Skipping $repoName (Current Repo)"
        continue
    }

    # Check exclusions
    if ($excludeList -contains $repoName) {
        Write-Host "  - Skipping $repoName (Excluded)"
        continue
    }

    # Check for hard exclusion by regex (like the original script had /nexus-workflows$)
    if ($repoName -match "/nexus-workflows$") {
        Write-Host "  - Skipping $repoName (Nexus Workflows)"
        continue
    }

    $finalRepos += $repoName
}

# Sort
$finalRepos = $finalRepos | Sort-Object -Unique

Write-Info "Found $($finalRepos.Count) repositories."

# Output JSON
$reposJson = $finalRepos | ConvertTo-Json -Compress
if ($finalRepos.Count -eq 1) { $reposJson = "[$reposJson]" }
if ($null -eq $finalRepos -or $finalRepos.Count -eq 0) { $reposJson = "[]" }

return $reposJson
