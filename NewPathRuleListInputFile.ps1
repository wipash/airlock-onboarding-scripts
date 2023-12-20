<#
.SYNOPSIS
    Creates an input file with group names to use with Add-PathList.ps1.
.DESCRIPTION
    Creates an input file with group names to use with Add-PathList.ps1.
    Loads API key and URL from a config file if it exists.
.PARAMETER File
    The file to write the new file to.
.PARAMETER APIKey
    Optional API key to use.
.PARAMETER AirlockURL
    Optional URL to use.
.EXAMPLE
    .\NewPathRuleListInputFile.ps1
.EXAMPLE
    .\NewPathRuleListInputFile.ps1 -File '.\NewPathRules.txt'
.EXAMPLE
    .\NewPathRuleListInputFile.ps1 -File '.\NewPathRules.txt' -APIKey '12345678-1234-1234-1234-123456789012' -AirlockURL 'https://airlock.example.com'
#>
[CmdletBinding()]
param
(
    [Parameter(Position = 0)]
    [string]$File = '.\NewPathRules.txt',
    [Parameter()]
    [string]$APIKey,
    [Parameter()]
    [string]$AirlockURL
)
Set-StrictMode -Version Latest

Import-Module -Name .\AirlockFunctions.psm1 -Force
Get-Config -APIKey $APIKey -AirlockURL $AirlockURL

$Groups = Get-GroupsFromAirlock

$TemplateContent = @()
$Groups | ForEach-Object {
    $TemplateContent += "## $($_.Name)`n`n"
}

$TemplateContent | Out-File -FilePath $File -Force
