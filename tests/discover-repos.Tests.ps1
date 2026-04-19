$scriptPath = Resolve-Path "$PSScriptRoot/../scripts/discover-repos.ps1"

Describe "discover-repos.ps1 (Air-Gapped)" {
    # Test variables
    $testOwner = "test-user"
    $testRepo  = "$testOwner/auto-repo"
    $manualRepo = "external-owner/manual-repo"
    $testQueries = "test-query" # Use a single query to speed up tests

    # FAIL-SAFE MOCKS: These functions replace external dependencies for this session.
    if (Get-Command -Name gh -CommandType Function -ErrorAction SilentlyContinue) { Remove-Item Function:\gh }
    if (Get-Alias -Name gh -ErrorAction SilentlyContinue) { Remove-Item Alias:\gh }

    function global:gh {
        param([string]$Arg1, [string]$Arg2, [string]$Arg3, [string]$Arg4, [string]$Arg5, [string]$Arg6, [string]$Arg7, [string]$Arg8, [string]$Arg9)

        $global:LASTEXITCODE = 0 # Simulate success

        if ($Arg1 -eq "search") {
            # Inspect actual arguments passed to the function
            $allArgs = $args + @($Arg1, $Arg2, $Arg3, $Arg4, $Arg5)
            $isCorrectUser = $false
            foreach ($arg in $allArgs) { if ($arg -like "*user:test-user*") { $isCorrectUser = $true } }

            if ($isCorrectUser) {
                return "[{`"repository`":{`"nameWithOwner`":`"test-user/auto-repo`"}}]"
            }
        }
        return "[]"
    }

    # PERFORMANCE MOCK: Mock Start-Sleep to make tests near-instant
    if (Get-Command -Name Start-Sleep -CommandType Function -ErrorAction SilentlyContinue) { Remove-Item Function:\Start-Sleep }
    function global:Start-Sleep { param($Seconds) }

    # Hide Write-Host output to keep test results clean
    if (Get-Command -Name Write-Host -CommandType Function -ErrorAction SilentlyContinue) { Remove-Item Function:\Write-Host }
    function global:Write-Host { param($Object) }

    It "Finds auto-discovered repositories (Optimized)" {
        # Using a single SearchQuery instead of the default 3 to reduce iterations
        $result = . $scriptPath -Owner $testOwner -SearchQueries $testQueries | ConvertFrom-Json

        $arr = @($result)
        $arr.Count | Should Be 1
        $arr -contains $testRepo | Should Be $true
    }

    It "Includes manual repositories (Optimized)" {
        $result = . $scriptPath -Owner $testOwner -IncludeRepos $manualRepo -SearchQueries $testQueries | ConvertFrom-Json

        $arr = @($result)
        $arr -contains $manualRepo | Should Be $true
        $arr -contains $testRepo | Should Be $true
        $arr.Count | Should Be 2
    }

    It "Bypasses exclusion filters (Optimized)" {
        $result = . $scriptPath -Owner $testOwner -IncludeRepos $manualRepo -ExcludeRepos $manualRepo -SearchQueries $testQueries | ConvertFrom-Json

        $arr = @($result)
        $arr -contains $manualRepo | Should Be $true
    }

    It "Correctly handles multiple manual repos (Optimized)" {
        $manual1 = "owner1/repo1"
        $manual2 = "owner2/repo2"
        $includeList = "$manual1, , $manual2 ,$manual1"

        $result = . $scriptPath -Owner $testOwner -IncludeRepos $includeList -SearchQueries $testQueries | ConvertFrom-Json

        $arr = @($result)
        $arr -contains $manual1 | Should Be $true
        $arr -contains $manual2 | Should Be $true
        $arr.Count | Should Be 3
    }

    It "Correctly handles complex exclusion lists (Optimized)" {
        $result = . $scriptPath -Owner $testOwner -ExcludeRepos "$testRepo, other/repo" -SearchQueries $testQueries | ConvertFrom-Json

        $arr = @($result)
        $arr.Count | Should Be 0
    }

    # Cleanup globals
    AfterAll {
        if (Get-Command -Name gh -CommandType Function -ErrorAction SilentlyContinue) { Remove-Item Function:\gh }
        if (Get-Command -Name Start-Sleep -CommandType Function -ErrorAction SilentlyContinue) { Remove-Item Function:\Start-Sleep }
        if (Get-Command -Name Write-Host -CommandType Function -ErrorAction SilentlyContinue) { Remove-Item Function:\Write-Host }
    }
}
