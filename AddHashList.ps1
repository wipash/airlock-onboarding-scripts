<#
.SYNOPSIS
    Add hashes to an application capture
.DESCRIPTION
    Add a list of hashes to an application capture. These hashes must already exist in the Airlock repository.
    Loads API key and URL from a config file if it exists.
.PARAMETER File
    The file to read the hashes from.
.PARAMETER AppCapture
    The name of the application capture to add the hashes to.
.PARAMETER APIKey
    Optional API key to use.
.PARAMETER AirlockURL
    Optional URL to use.
.EXAMPLE
    .\AddHashList.ps1 -File '.\NewHashes.txt' -AppCapture 'MyApp'
#>
[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [string]$File,
    [Parameter(Mandatory = $true)]
    [string]$AppCapture,
    [Parameter()]
    [string]$APIKey,
    [Parameter()]
    [string]$AirlockURL
)

Set-StrictMode -Version Latest
Import-Module -Name .\AirlockFunctions.psm1 -Force
Get-Config -APIKey $APIKey -AirlockURL $AirlockURL


$HashFileContent = Get-Content -Path $File | Where-Object { $_ -and $_.Trim() } | Where-Object {$_.Length -eq 64}

$AppCaptures = Get-AppCapturesFromAirlock
$AppCaptureID = $AppCaptures | Where-Object {$_.Name -eq $AppCapture} | Select-Object -First 1 -ExpandProperty ID
if (!$AppCaptureID) {
    Write-Host -ForegroundColor Red "Application capture '$AppCapture' not found"
    exit
}

Write-Host -ForegroundColor DarkGreen 'I found:'
Write-Host -ForegroundColor Green "$($HashFileContent.Count) hashes"

$title = ''
$question = 'Add them?'
$choices = '&Yes', '&No'
$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
if ($decision -eq 1) {
    exit
}

Add-HashesToApplicationCapture -ApplicationID $AppCaptureID -SHA256Hashes $HashFileContent

Write-Host -ForegroundColor Green 'Hashes added to AppCapture'

