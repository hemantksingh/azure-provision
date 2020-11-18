param (
    [Parameter(mandatory = $true)][string] $stackName,
    [Parameter(mandatory = $true)][string] $azureRegion,
    [string] $deployedBy='hk'
)
$ErrorActionPreference = "Stop"

$config = @{
    stack_name           = $stackName
    azure_region         = $azureRegion
    deployed_by          = $deployedBy
}

$currentDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$tfVarsFile = "$currentDir/vars.auto.tfvars.json"
  
Write-Host "Writing config to $tfVarsFile"
$config | ConvertTo-Json | Out-File -Encoding ASCII $tfVarsFile