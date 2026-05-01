Describe "discover-repos.ps1 (The Final Scoping Pass)" {
    BeforeAll {
        $global:scriptPath = (Join-Path -Path $PSScriptRoot -ChildPath "../scripts/discover-repos.ps1" | Resolve-Path).Path

        # Environmental Isolation
        $env:GH_TOKEN = $null
        $env:CI = "true"

        # Encapsulated helper function to ensure visibility in It blocks
        function Test-DiscoveryLogic {
            param($Owner, $Queries, $Inclusions = "", $Exclusions = "", $Mock)
            $env:UNEX_OWNER = $Owner
            $env:UNEX_SEARCH_QUERIES = $Queries
            $env:UNEX_INCLUDE_REPOS = $Inclusions
            $env:UNEX_EXCLUDE_REPOS = $Exclusions
            $env:MOCK_GH_RESULT = $Mock

            $raw = & $global:scriptPath
            return $raw | ConvertFrom-Json
        }
    }

    BeforeEach {
        $env:UNEX_OWNER = $null
        $env:UNEX_SEARCH_QUERIES = $null
        $env:UNEX_INCLUDE_REPOS = $null
        $env:UNEX_EXCLUDE_REPOS = $null
        $env:MOCK_GH_RESULT = '[]'
    }

    It "Finds auto-discovered repositories" {
        $mock = '[{"repository":{"nameWithOwner":"test-user/auto-repo"}}]'
        $result = Test-DiscoveryLogic -Owner "test-user" -Queries "test-query" -Mock $mock

        $arr = @($result)
        $arr.Count | Should -Be 1
        $arr -contains "test-user/auto-repo" | Should -Be $true
    }

    It "Includes manual repositories" {
        $mock = '[{"repository":{"nameWithOwner":"test-user/auto-repo"}}]'
        $result = Test-DiscoveryLogic -Owner "test-user" -Queries "test-query" -Inclusions "test-owner/manual-repo" -Mock $mock

        $arr = @($result)
        $arr -contains "test-owner/manual-repo" | Should -Be $true
        $arr -contains "test-user/auto-repo" | Should -Be $true
        $arr.Count | Should -Be 2
    }

    It "Bypasses exclusion filters" {
        $mock = '[{"repository":{"nameWithOwner":"test-user/auto-repo"}}]'
        $result = Test-DiscoveryLogic -Owner "test-user" -Queries "test-query" -Inclusions "test-owner/manual-repo" -Exclusions "test-owner/manual-repo" -Mock $mock

        $arr = @($result)
        $arr -contains "test-owner/manual-repo" | Should -Be $true
    }

    It "Correctly handles complex exclusion lists" {
        $mock = '[{"repository":{"nameWithOwner":"test-user/auto-repo"}}, {"repository":{"nameWithOwner":"test-user/other-repo"}}]'
        $result = Test-DiscoveryLogic -Owner "test-user" -Queries "test-query" -Exclusions "test-user/auto-repo, test-user/other-repo" -Mock $mock

        $arr = @($result)
        $arr.Count | Should -Be 0
    }

    It "Deduplicates repos when multiple owners are searched" {
        # Both owners return the same repo; it should appear only once.
        $mock = '[{"repository":{"nameWithOwner":"test-user/shared-repo"}}]'
        $result = Test-DiscoveryLogic -Owner "test-user, other-owner" -Queries "test-query" -Mock $mock

        $arr = @($result)
        $arr.Count | Should -Be 1
        $arr -contains "test-user/shared-repo" | Should -Be $true
    }

    AfterAll {
        $env:MOCK_GH_RESULT = $null
        $env:UNEX_OWNER = $null
        $env:UNEX_SEARCH_QUERIES = $null
    }
}
