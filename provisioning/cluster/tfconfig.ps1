param (
    [string] $targetEnv='lolcat',
    [string] $resourceGroupName='playground',
    [string] $azureRegion='westeurope',
    [string] $deployedBy='hk'
)
$ErrorActionPreference = "Stop"

$config = @{
    target_env           = $targetEnv
    stack_resource_group = $resourceGroupName
    azure_region         = $azureRegion
    deployed_by          = $deployedBy
}

$currentDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$tfVarsFile = "$currentDir/vars.auto.tfvars.json"
  
Write-Host "Writing config to $tfVarsFile"
$config | ConvertTo-Json | Out-File -Encoding ASCII $tfVarsFile