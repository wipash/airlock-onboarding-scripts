<#
.SYNOPSIS
    Generates a report of all executions for a policy group.
.DESCRIPTION
    Evaluates all executions from a report file against a list of current hash, publisher and path rules.
    Loads API key and URL from a config file if it exists.
.PARAMETER HashFile
    The path to a CSV file containing a list of allowed hashes.
    This file is created by exporting an Airlock application capture to CSV.
.PARAMETER ReportFile
    The path to a CSV file containing a list of executions.
    This file is created by running an Airlock search and exporting the results to CSV.
.PARAMETER PolicyGroup
    The name of the policy group to evaluate.
.PARAMETER OutputFile
    The path to save the report to.
    If not specified, the report will be saved to the current directory with a timestamp in the filename.
.PARAMETER APIKey
    Optional API key to use.
.PARAMETER AirlockURL
    Optional URL to use.
.EXAMPLE
    .\NewExecutionReport.ps1 -HashFile '.\AllowedAppHashes.csv' -ReportFile '.\ExecutionHistory.csv' -PolicyGroup 'Windows 10' -OutputFile '.\ExecutionReport.csv'
#>
[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [string]$HashFile,
    [Parameter(Mandatory = $true)]
    [string]$ReportFile,
    [Parameter(Mandatory = $true)]
    [string]$PolicyGroup,
    [Parameter()]
    [string]$OutputFile,
    [Parameter()]
    [string]$APIKey,
    [Parameter()]
    [string]$AirlockURL
)

Set-StrictMode -Version Latest
Import-Module .\AirlockFunctions.psm1 -Force
Get-Config -APIKey $APIKey -AirlockURL $AirlockURL


<#
.SYNOPSIS
    Tests a path against a list of compiled regex patterns.
.DESCRIPTION
    Tests a path against a list of compiled regex patterns.
    Returns the first matching path rule, or $false if no rules match.
.PARAMETER PathRulesWithCompiledPatterns
    A list of path rules with compiled regex patterns.
.PARAMETER Path
    The path to test.
.EXAMPLE
    Test-PathMatch -PathRulesWithCompiledPatterns $PathRulesWithCompiledPatterns -Path 'C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE'
#>
function Test-PathMatch {
    param (
        [PSCustomObject[]]$PathRulesWithCompiledPatterns,
        [string]$Path
    )

    foreach ($rule in $PathRulesWithCompiledPatterns) {
        $regexPattern = $rule.RegexPattern
        if ($Path -match $regexPattern) {
            return $rule.PathRule
        }
    }

    return $false
}

<#
.SYNOPSIS
    Tests that a CSV has the required columns.
.DESCRIPTION
    Tests that a CSV has the required columns.
    Warns and exits the script if a column is missing.
.PARAMETER CsvData
    The CSV data to test.
.PARAMETER RequiredColumns
    List of required columns names.
.PARAMETER CsvName
    The name of the CSV file being tested.
.EXAMPLE
    Test-RequiredColumns -CsvData $AllowedAppHashes -RequiredColumns $requiredColumns -CsvName 'Hash file'
#>
function Test-RequiredColumns {
    param (
        [PSCustomObject]$CsvData,
        [string[]]$RequiredColumns,
        [string]$CsvName
    )

    foreach ($column in $RequiredColumns) {
        if ($null -eq $CsvData.$column) {
            Write-Host -ForegroundColor Red "$CsvName is missing a column named '$column'"
            exit
        }
    }
}

# Get the ID of the named policy group
$Groups = Get-GroupsFromAirlock
$GroupID = $Groups | Where-Object { $_.Name -eq $PolicyGroup } | Select-Object -ExpandProperty ID
if ($null -eq $GroupID) {
    Write-Host -ForegroundColor Red "Couldn't find a group named '$PolicyGroup'"
    exit
}

Write-Host -ForegroundColor Green "Importing CSVs"
$AllowedAppHashes = Import-Csv -Path $HashFile -ErrorAction Stop
$ExecutionHistory = Import-Csv -Path $ReportFile -ErrorAction Stop

# Make sure the CSVs have the required columns
$requiredHashColumns = @('SHA-256')
$requiredReportColumns = @('Client - Group', 'File - File Path', 'File - File Name', 'Hash - SHA256', 'File - Publisher', 'Client - Hostname', 'Client - User')

Test-RequiredColumns -CsvData $AllowedAppHashes -RequiredColumns $requiredHashColumns -CsvName 'Hash file'
Test-RequiredColumns -CsvData $ExecutionHistory -RequiredColumns $requiredReportColumns -CsvName 'Report file'

# Filter out all the unnecessary data from the CSVs
$AllowedAppHashes = $AllowedAppHashes | Select-Object -ExpandProperty 'SHA-256'
$ExecutionHistory = $ExecutionHistory | Where-Object { $_.'Client - Group' -eq $PolicyGroup }

Write-Host -ForegroundColor Yellow "  Total execution events to be evaluated: $($ExecutionHistory.Count)"

Write-Host -ForegroundColor Green "Getting path and publisher rules from Airlock API"
$PathsAndPublishers = Get-GroupRulesFromAirlock $GroupID
$AllowedPathRules = $PathsAndPublishers.Paths
$AllowedPublishers = $PathsAndPublishers.Publishers

Write-Host -ForegroundColor Yellow "  Allowed hashes: $($AllowedAppHashes.Count)"
Write-Host -ForegroundColor Yellow "  Allowed paths: $($AllowedPathRules.Count)"
Write-Host -ForegroundColor Yellow "  Allowed publishers: $($AllowedPublishers.Count)"

# Precomiple the regex patterns for the path rules to save a bit of time, it's still super slow though
Write-Host -ForegroundColor Green "Compiling path rule regex patterns"
$PathRulesWithCompiledPatterns = @()
foreach ($rule in $AllowedPathRules) {
    $regexPattern = [regex]::Escape($rule)
    # Convert Airlock wildcard syntax to regex syntax
    $regexPattern = $regexPattern -replace '\\\*\\\*', '.*' -replace '\\\*', '[^\\]*' -replace '\\\?', '.'
    $PathRulesWithCompiledPatterns += [PSCustomObject]@{
        'PathRule'     = $rule
        'RegexPattern' = "^$regexPattern$"
    }
}

Write-Progress -Activity 'Building execution report' -Status "" -PercentComplete 0

$ExecutionReport = @()
foreach ($Execution in $ExecutionHistory) {
    if ($ExecutionHistory.IndexOf($Execution) % 100 -eq 0) {
        $Index = $ExecutionHistory.IndexOf($Execution)
        $PercentComplete = [math]::Round(($Index / $ExecutionHistory.Count) * 100)
        Write-Progress -Activity 'Building execution report' -Status "($($Index) of $($ExecutionHistory.Count))" -PercentComplete $PercentComplete
    }

    $Path = $Execution.'File - File Path' + $Execution.'File - File Name'
    $Hash = $Execution.'Hash - SHA256'
    $MatchesPathRule = Test-PathMatch -PathRulesWithCompiledPatterns $PathRulesWithCompiledPatterns -Path $Path
    $MatchesPublisher = $AllowedPublishers -contains $Execution.'File - Publisher'
    $IsAllowedHash = $AllowedAppHashes -contains $Hash

    $ExecutionReport += [PSCustomObject]@{
        'Folder'          = $Execution.'File - File Path'
        'File'            = $Execution.'File - File Name'
        'Hash'            = $Hash
        'Publisher'       = $Execution.'File - Publisher'
        'Hostname'        = $Execution.'Client - Hostname'
        'User'            = $Execution.'Client - User'
        'MatchesPathRule' = $MatchesPathRule ? $MatchesPathRule : ''
        'MatchesPublisher'= $MatchesPublisher
        'IsAllowedHash'   = $IsAllowedHash
        'WouldBeBlocked'  = -not $MatchesPathRule -and -not $IsAllowedHash -and -not $MatchesPublisher
    }
}
Write-Progress -Activity 'Building execution report' -Status "Complete" -Completed
Write-Host -ForegroundColor Green 'Execution report complete'

# Remove duplicate paths (where Folder + File is a duplicate)
$ExecutionReport = $ExecutionReport | Sort-Object -Property Folder, File -Unique
$ExecutionReport = $ExecutionReport | Sort-Object -Property Folder, File, Hash

$DateTime = Get-Date -Format 'yyyyMMdd-HHmmss'
$OutputFile = $OutputFile ? $OutputFile : ".\ExecutionReport-$DateTime.csv"
Write-Host -ForegroundColor Green "Report saved to $OutputFile"

$ExecutionReport | Export-Csv -Path $OutputFile -NoTypeInformation
