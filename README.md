# airlock-onboarding-scripts
This is a set of scripts to help with onboarding and maintenance of an Airlock Digital instance.

All scripts will attempt to load your Airlock URL and API key from `airlockconfig.conf`, and will accept the URL and key as parameters or prompt if they're missing.

## `GetAllPathRules.ps1`
Outputs a set of text files containing all path rules for all policy groups


## `NewPathRuleListInputFile.ps1`
Generates a text file containing headings for each policy group name, to be used as a starting point for [`AddPathRuleList.ps1`](#addhashlistps1)


## `AddPathRuleList.ps1`
Takes a text file containing any number of path rules, grouped under headings that match the names of your Airlock policy groups. The file doesn't need to contain all group names, only the ones you want to add rules to. Any rules that already exist in that group will be skipped (Airlock's API handles that) so you won't end up with duplicates.

#### Example file content:
```
## Workstations
C:\Users\*\AppData\Local\assembly\dl3\????????.???\????????.???\????????\????????_????????\CustomSolution.DLL
C:\Program Files\Microsoft Visual Studio\20??\Professional\**.tlb

## Windows Servers
C:​\Program Files​\AppVendor\MyApp ?.?.?.?​\Common Files​\win64​\lib​\*.dll
```


## `UpdatePolicyGroupPathRules.ps1`
Takes a path rule list and compares it to the current path rules for a specific policy group. Rules are then added or removed so that the policy group's path rules match those in the file. This is handy for making bulk edits to the rules in a policy group.

I suggest running [`GetAllPathRules.ps1`](#getallpathrulesps1) and then making edits to the relevant output file, and then using that file as the input to `UpdatePolicyGroupPathRules.ps1`.


## `AddHashList.ps1`
Takes a text file containing any number of SHA256 hashes and adds them to a specified application capture. The hashes must already exist in the Airlock repository (eg Airlock has seen the files before, blocked or not).

If you want to add hashes that Airlock has not seen before, you'll need to do something like:
```powershell
Import-Module -Name .\AirlockFunctions.psm1 -Force
Get-Config -APIKey $APIKey -AirlockURL $AirlockURL
$HashesAndPaths = Import-CSV '.\yourcsv.csv' # Assuming a CSV with columns 'Hash' and 'Path'
$AddHashesBody = @{'hashes' = @()}
$HashesAndPaths | ForEach-Object {
    $AddHashesBody.hashes += @{
        'sha256' = $_.Hash
        'path' = $_.Path
    }
}

Invoke-AirlockAPICall -Endpoint '/v1/hash/add' -Body ($AddHashesBody | ConvertTo-Json)
```


## `NewExecutionReport.ps1`
This script evaluates a list of past executions against your current rules, and outputs the report in CSV format.
This is useful when nearing the end of an audit phase in an Airlock deployment, and you want to make sure that your rule set hasn't missed anything.

#### Generating the report:
1. Run a search in Airlock, ensure that it includes the following columns (in any order)
   - `Client - Group`
   - `File - File Path`
   - `File - File Name`
   - `Hash - SHA256`
   - `File - Publisher`
   - `Client - Hostname`
   - `Client - User`
2. Save the report to a CSV file
3. Export the Application Capture that you want to test against as a CSV package (this is easiest way I can find to get a list of all hash rules)
4. Run `NewExecutionReport.ps1` with the following parameters:
   - `-HashFile` - Path to the application capture CSV file
   - `-ReportFile` - Path to the downloaded search results CSV file
