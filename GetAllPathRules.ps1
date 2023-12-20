<#
.SYNOPSIS
    Gets all path rules for all groups and exports them to separate files.
.DESCRIPTION
    Gets all path rules for all groups and exports them to separate files.
    Overwrites existing files.
    Loads API key and URL from a config file if it exists.
.PARAMETER OutputDirectory
    The directory to write the new files to.
.PARAMETER APIKey
    Optional API key to use.
.PARAMETER AirlockURL
    Optional URL to use.
.EXAMPLE
    .\GetAllPathRules.ps1
.EXAMPLE
    .\GetAllPathRules.ps1 -OutputDirectory '.\PathRules'
.EXAMPLE
    .\GetAllPathRules.ps1 -OutputDirectory '.\PathRules' -APIKey '12345678-1234-1234-1234-123456789012' -AirlockURL 'https://airlock.example.com'
#>
[CmdletBinding()]
param
(
    [Parameter(Position = 0)]
    [string]$OutputDirectory = '.',
    [Parameter()]
    [string]$APIKey,
    [Parameter()]
    [string]$AirlockURL
)
Set-StrictMode -Version Latest
Import-Module .\AirlockFunctions.psm1 -Force
Get-Config -APIKey $APIKey -AirlockURL $AirlockURL

$Groups = Get-GroupTreeFromAirlock -Verbose:($VerbosePreference -eq 'Continue')

$Groups | ForEach-Object {
    $Rules = @(Get-GroupRulesFromAirlock -GroupId $_.ID -Verbose:($VerbosePreference -eq 'Continue'))
    $Paths = $Rules.Paths
    if ($Paths.Count -ne 0) {
        $Paths | Out-File -Path "$OutputDirectory\PathRules-$($_.Name).txt" -Force
    }
    # If the group has child groups, get the unique paths for each child group and export them
    if ($_.Children) {
        $_.Children | ForEach-Object {
            $ChildRules = @(Get-GroupRulesFromAirlock $_.ID -Verbose:($VerbosePreference -eq 'Continue'))
            $ChildPaths = $ChildRules.Paths
            $FilteredChildPaths = @($ChildPaths | Where-Object { $_ -notin $Paths })
            if ($FilteredChildPaths.Count -ne 0) {
                $FilteredChildPaths | Out-File -Path "$OutputDirectory\PathRules-$($_.Name).txt" -Force
            }
        }
    }
}
