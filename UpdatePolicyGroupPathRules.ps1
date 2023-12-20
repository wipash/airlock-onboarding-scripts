<#
.SYNOPSIS
    Updates the path rules for a policy group to match a file.
.DESCRIPTION
    Updates the path rules for a policy group by adding and removing rules so that it matches the content of an input file.
    Loads API key and URL from a config file if it exists.
.PARAMETER File
    The file containing the desired state of the policy group's path rules.
.PARAMETER Group
    The name of the policy group to update.
.PARAMETER APIKey
    Optional API key to use.
.PARAMETER AirlockURL
    Optional URL to use.
.EXAMPLE
    .\UpdatePolicyGroupPathRules.ps1 -File '.\PathRules\PathRules-Group1.txt' -Group 'Group1'
#>
[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [string]$File,
    [Parameter(Mandatory = $true)]
    [string]$Group,
    [Parameter()]
    [string]$APIKey,
    [Parameter()]
    [string]$AirlockURL
)

Set-StrictMode -Version Latest
Import-Module -Name .\AirlockFunctions.psm1 -Force
Get-Config -APIKey $APIKey -AirlockURL $AirlockURL

$Groups = Get-GroupsFromAirlock
$GroupID = $Groups | Where-Object { $_.Name -eq $Group } | Select-Object -First 1 -ExpandProperty ID
if (!$GroupID) {
    Write-Host -ForegroundColor Red "Group '$Group' not found"
    exit
}

$CurrentPaths = Get-GroupRulesFromAirlock -GroupId $GroupID

$PathsFromFile = Get-Content -Path $File | Where-Object { $_ -and $_.Trim() } | Get-CleanPathRule


# Work out what to remove
$PathsToRemove = $CurrentPaths | Where-Object { $PathsFromFile -notcontains $_ }

# Work out what to add
$PathsToAdd = $PathsFromFile | Where-Object { $CurrentPaths -notcontains $_ }

Write-Host -ForegroundColor DarkGreen "Paths I'm going to remove: "
$PathsToRemove | ForEach-Object {
    Write-Host -ForegroundColor Red "$_"
}

Write-Host -ForegroundColor DarkGreen "Paths I'm going to add: "
$PathsToAdd | ForEach-Object {
    Write-Host -ForegroundColor Green "$_"
}

$title = ''
$question = 'Happy with that?'
$choices = '&Yes', '&No'
$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
if ($decision -eq 1) {
    exit
}

Write-Host -ForegroundColor DarkGreen 'Removing paths:'
$PathsToRemove | ForEach-Object {
    Remove-GroupPathRuleFromAirlock -Path $_ -GroupID $GroupID
}

Write-Host -ForegroundColor DarkGreen 'Adding paths:'
$PathsToAdd | ForEach-Object {
    Add-GroupPathRuleToAirlock -Path $_ -GroupID $GroupID
}
