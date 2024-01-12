$Script:AirlockConfig = [ordered]@{
    AirlockURL = $null
    APIKey     = $null
}

Set-StrictMode -Version Latest

<#
.SYNOPSIS
    Invokes an API call to Airlock.
.DESCRIPTION
    Invokes an API call to Airlock, using the API key and URL stored in the $AirlockConfig variable.
    All Airlock API calls are POST requests, so this function only supports POST requests.
.PARAMETER Endpoint
    The API endpoint to call.
.PARAMETER Body
    Optional body of the API call.
.EXAMPLE
    Invoke-AirlockAPICall -Endpoint '/v1/group' -Body $Body
#>
function Invoke-AirlockAPICall {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Endpoint,
        [Parameter()]
        [string]$Body = $null
    )
    $Headers = @{
        'X-APIKEY' = $Script:AirlockConfig.APIKey
    }

    $AirlockURL = $Script:AirlockConfig.AirlockURL.TrimEnd('/')
    $Endpoint = $Endpoint.TrimStart('/')

    $Result = Invoke-RestMethod -Uri "$AirlockURL/$Endpoint" -Method Post -Body $Body -Headers $Headers -ContentType 'application/json'

    if ($Result.error -ne 'Success') {
        $APIError = "Error calling $($Endpoint): $($Result.error)"
        throw $APIError
    }

    return $Result
}

<#
.SYNOPSIS
    Gets a list of application captures from the Airlock API.
.DESCRIPTION
    Gets a list of application captures from the Airlock API.
.Example
    Get-AppCapturesFromAirlock
#>
function Get-AppCapturesFromAirlock {
    [CmdletBinding()]
    param()
    Write-Verbose 'Getting application captures from Airlock'
    $Result = Invoke-AirlockAPICall -Endpoint '/v1/application'

    $AppCaptures = $Result.response.applications

    return $AppCaptures | ForEach-Object {
        [PSCustomObject]@{
            Name    = $_.name
            ID      = $_.applicationid
            Version = $_.version
        }
    }
}

<#
.SYNOPSIS
    Adds a list of hashes to an application capture in Airlock.
.DESCRIPTION
    Adds a list of hashes to an application capture in Airlock.
.PARAMETER ApplicationID
    The ID of the application capture to add the hashes to.
.PARAMETER SHA256Hashes
    The list of SHA256 hashes to add to the application capture.
.EXAMPLE
    Add-HashesToApplicationCapture -ApplicationID '12345678-1234-1234-1234-123456789012' -SHA256Hashes @('1234567890123456789012345678901234567890123456789012345678901234', '2345678901234567890123456789012345678901234567890123456789012345')
#>
function Add-HashesToApplicationCapture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApplicationID,
        [Parameter(Mandatory = $true)]
        [string[]]$SHA256Hashes
    )
    $Body = @{
        applicationid = $ApplicationID
        hashes        = $SHA256Hashes
    } | ConvertTo-Json

    Write-Verbose "Adding hash list to application capture $ApplicationID"
    Invoke-AirlockAPICall -Endpoint '/v1/hash/application/add' -Body $Body | Out-Null
}

<#
.SYNOPSIS
    Gets a list of rules from the Airlock API.
.DESCRIPTION
    Gets a sorted list of both path and publisher rules for a specific group from the Airlock API.
.PARAMETER GroupId
    The ID of the group to get rules for.
.EXAMPLE
    Get-GroupRulesFromAirlock -GroupId '12345678-1234-1234-1234-123456789012'
#>
function Get-GroupRulesFromAirlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$GroupId
    )
    $body = @{
        groupid = $GroupID
    } | ConvertTo-Json

    Write-Verbose "Getting paths for group $GroupId"
    $Result = Invoke-AirlockAPICall -Endpoint '/v1/group/policies' -Body $body

    if ($null -eq $Result.response.paths) {
        $Paths = @()
    }
    else {
        $Paths = $Result.response.paths | ForEach-Object {
            $_.name -replace '\\\\', '\'
        }
    }
    if ($null -eq $Result.response.publishers) {
        $Publishers = @()
    }
    else {
        $Publishers = $Result.response.publishers | ForEach-Object {
            $_.name
        }
    }

    $Paths = @($Paths | Sort-Object)
    $Publishers = @($Publishers | Sort-Object)

    return [PSCustomObject]@{
        'Paths'      = $Paths
        'Publishers' = $Publishers
    }
}

<#
.SYNOPSIS
    Adds a path rule to a group in Airlock.
.DESCRIPTION
    Adds a path rule to a group in Airlock.
.PARAMETER GroupId
    The ID of the group to add the path rule to.
.PARAMETER PathRule
    The path rule to add to the group.
.EXAMPLE
    Add-GroupPathRuleToAirlock -GroupId '12345678-1234-1234-1234-123456789012' -PathRule 'C:\Program Files\*'
#>
function Add-GroupPathRuleToAirlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$GroupId,
        [Parameter(Mandatory = $true)]
        [string]$PathRule
    )
    $Body = @{
        groupid = $GroupID
        path    = $PathRule
    } | ConvertTo-Json

    Write-Verbose "Adding path $PathRule to group $GroupId"
    Invoke-AirlockAPICall -Endpoint '/v1/group/path/add' -Body $Body | Out-Null
    Write-Host -ForegroundColor Green "$PathRule"
}

<#
.SYNOPSIS
    Removes a path rule to a group in Airlock.
.DESCRIPTION
    Removes a path rule to a group in Airlock.
.PARAMETER GroupId
    The ID of the group to remove the path rule from.
.PARAMETER PathRule
    The path rule to remove from the group.
.EXAMPLE
    Remove-GroupPathRuleToAirlock -GroupId '12345678-1234-1234-1234-123456789012' -PathRule 'C:\Program Files\*'
#>
function Remove-GroupPathRuleFromAirlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$GroupId,
        [Parameter(Mandatory = $true)]
        [string]$PathRule
    )
    $Body = @{
        groupid = $GroupID
        path    = $PathRule
    } | ConvertTo-Json

    Write-Verbose "Removing path $PathRule from group $GroupId"
    Invoke-AirlockAPICall -Endpoint '/v1/group/path/remove' -Body $Body | Out-Null
    Write-Host -ForegroundColor Red "$PathRule"
}


<#
.SYNOPSIS
    Gets a list of all groups from Airlock.
.DESCRIPTION
    Gets a list of all groups from Airlock.
.EXAMPLE
    Get-GroupsFromAirlock
#>
function Get-GroupsFromAirlock {
    [CmdletBinding()]
    param()
    Write-Verbose 'Getting groups from Airlock'
    $Result = Invoke-AirlockAPICall -Endpoint '/v1/group'

    $Groups = $Result.response.groups

    return $Groups | ForEach-Object {
        [PSCustomObject]@{
            Name   = $_.name
            ID     = $_.groupid
            Parent = $_.parent
        }
    }
}

<#
.SYNOPSIS
    Gets a tree of all groups from Airlock.
.DESCRIPTION
    Gets all groups from Airlock and builds a tree of groups based on the parent/child relationship.
.EXAMPLE
    Get-GroupTreeFromAirlock
#>
function Get-GroupTreeFromAirlock {
    [CmdletBinding()]
    param()

    $Groups = Get-GroupsFromAirlock

    $ParentGroups = $Groups | Where-Object { $_.Parent -eq 'global-policy-settings' } | ForEach-Object {
        $_ | Add-Member -MemberType NoteProperty -Name Children -Value @() -PassThru
    }

    $ChildGroups = $Groups | Where-Object { $_.Parent -ne 'global-policy-settings' }

    foreach ($Group in $ChildGroups) {
        $ParentGroup = $ParentGroups | Where-Object { $_.ID -eq $Group.Parent } | Select-Object -First 1
        if ($ParentGroup) {
            $ParentGroup.Children += $Group
        }
    }

    return $ParentGroups
}

<#
.SYNOPSIS
    Cleans up a path rule.
.DESCRIPTION
    Cleans up a path rule by removing zero-width space characters and validating the path.
.PARAMETER PathRule
    The path rule to clean up.
.EXAMPLE
    Get-CleanPathRule -PathRule 'C:\Program Files\*'
.EXAMPLE
    $CleanPathRules = $PathRuleList | Get-CleanPathRule
#>
function Get-CleanPathRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$PathRule
    )
    begin {
        $PathRules = @()
    }
    process {
        # If you copied and pasted paths direct from Airlock, you probably copied a bunch of zero-width space characters too.
        # This removes them. See: https://stackoverflow.com/a/68328388
        $PathRule = $PathRule.Trim() -creplace '\P{IsBasicLatin}'
        # Make sure the path looks like a path
        # - Starts with a drive letter like C:\ or \\ (UNC path)
        # - Has a file extension between 1 and 10 characters long
        # - Or ends in * (wildcard)
        # ^(?:[a-z]:\\)|(\\\\).*(\.\w{1,10}|\*+)$
        if ($PathRule -match '^([a-z]:\\|\\\\).*(\.\w{1,10}|\*)$') {
            $PathRules += $PathRule
        }
    }
    end {
        if ($PathRules.Count -eq 1) {
            return $PathRules[0]
        }
        return $PathRules
    }

}

<#
.SYNOPSIS
    Gets a list of path rules from a file for a specific group.
.DESCRIPTION
    Gets a list of path rules for a specific group from a file containing Airlock paths grouped by group names.
.PARAMETER PathList
    The contents of a file containing Airlock path rules.
.PARAMETER Identifier
    The identifier for the group of paths to get from the file.
.EXAMPLE
    Get-GroupPathRulesFromFileContent -PathList $PathFileContent -Identifier 'Workstations'
#>
function Get-GroupPathRulesFromFileContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$PathList,
        [Parameter(Mandatory = $true)]
        [string]$Identifier
    )
    $ReturnPaths = $null

    foreach ($Path in $PathList) {
        if ($Path -match "^## $Identifier") {
            $ReturnPaths = @(' ')
            continue
        }
        elseif ($ReturnPaths) {
            if ($Path -match '^##') {
                break
            }
            $CleanPathRule = Get-CleanPathRule -PathRule $Path
            if ($null -ne $CleanPathRule) {
                $ReturnPaths += $CleanPathRule
            }
        }
    }
    if ($ReturnPaths) {
        $ReturnPaths = $ReturnPaths | Where-Object { $_ -and $_.Trim() }
    }
    return $ReturnPaths
}

<#
.SYNOPSIS
    Gets the config for this module from a file.
.DESCRIPTION
    Gets the config for this module from a file.
.PARAMETER ConfigFilePath
    Optional path to the config file.
.EXAMPLE
    Get-ConfigFromFile -ConfigFilePath '.\airlockconfig.conf'
#>
function Get-ConfigFromFile {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigFilePath = '.\airlockconfig.conf'
    )
    $Config = @{}
    if (Test-Path -Path $ConfigFilePath) {
        $ConfigFileContent = Get-Content -Path $ConfigFilePath | Where-Object { $_ -and $_.Trim() }
        foreach ($i in $ConfigFileContent) {
            $Config.Add($i.split('=')[0], $i.split('=', 2)[1])
        }
    }
    return $Config
}

<#
.SYNOPSIS
    Gets the config for this module.
.DESCRIPTION
    Gets the config for this module. Accepts optional parameters, which will override the config file.
    Prompts for any missing config values.
.PARAMETER APIKey
    Optional API key to use.
.PARAMETER AirlockURL
    Optional URL to use.
.EXAMPLE
    Get-Config -APIKey '12345678-1234-1234-1234-123456789012' -AirlockURL 'https://airlock.example.com'
#>
function Get-Config {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$APIKey,
        [Parameter()]
        [string]$AirlockURL
    )
    $Config = Get-ConfigFromFile

    if ($APIKey) {
        $Script:AirlockConfig.APIKey = $APIkey
    }
    elseif ($Config.APIKey) {
        $Script:AirlockConfig.APIKey = $Config.APIKey
    }
    else {
        $Script:AirlockConfig.APIKey = Read-Host -Prompt 'Enter your Airlock API key'
    }

    if ($AirlockURL) {
        $Script:AirlockConfig.AirlockURL = $AirlockURL
    }
    elseif ($Config.AirlockURL) {
        $Script:AirlockConfig.AirlockURL = $Config.AirlockURL
    }
    else {
        $Script:AirlockConfig.AirlockURL = Read-Host -Prompt 'Enter your Airlock URL'
    }
}
