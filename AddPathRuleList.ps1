<#
.SYNOPSIS
    Adds path rules to groups from a file.
.DESCRIPTION
    Adds path rules to groups from a file.
    Groups are identified by name headers in the input file, eg '## Group Name'.
    You can use New-PathListInputFile.ps1 to create an input file with all existing group names.
    Path rules have some simple validation applied to them, eg:
        - Starts with a drive letter like C:\
        - Has a file extension between 1 and 10 characters long
        - Or ends in * or ** (wildcard)
    Loads API key and URL from a config file if it exists.
.PARAMETER File
    The file to read the path rules from.
.PARAMETER APIKey
    Optional API key to use.
.PARAMETER AirlockURL
    Optional URL to use.
.EXAMPLE
    .\AddPathRuleList.ps1 -File '.\NewPathRules.txt'
.EXAMPLE
    .\AddPathRuleList.ps1 -File '.\NewPathRules.txt' -APIKey '12345678-1234-1234-1234-123456789012' -AirlockURL 'https://airlock.example.com'
#>
[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$File,
    [Parameter()]
    [string]$APIKey,
    [Parameter()]
    [string]$AirlockURL
)
Set-StrictMode -Version Latest
Import-Module -Name .\AirlockFunctions.psm1 -Force
Get-Config -APIKey $APIKey -AirlockURL $AirlockURL

$PathFileContent = Get-Content -Path $File | Where-Object { $_ -and $_.Trim() }

$Groups = Get-GroupsFromAirlock

$PathRules = @{}

Write-Host -ForegroundColor DarkGreen 'I found:'
$Groups | ForEach-Object {
    $ID = $_.ID
    $Name = $_.Name
    $PathRules[$ID] = @(Get-GroupPathRulesFromFileContent -PathList $PathFileContent -Identifier $Name | Where-Object {$_})
    if ($PathRules[$ID].Count -gt 0) {
        Write-Host -ForegroundColor Green "$($PathRules[$ID].Count) $($Name) paths"
        Write-Verbose "`n$($PathRules[$ID] -join "`n")"
    }
}

$title = ''
$question = 'Add them?'
$choices = '&Yes', '&No'
$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
if ($decision -eq 1) {
    exit
}


$Groups | ForEach-Object {
    $ID = $_.ID
    $Paths = $PathRules[$ID]
    if ($Paths.Count -eq 0) {
        return
    }
    $Paths | ForEach-Object {
        #Write-Host -ForegroundColor Red "$_"
        Add-GroupPathRuleToAirlock -GroupId $ID -PathRule $_
    }
}
