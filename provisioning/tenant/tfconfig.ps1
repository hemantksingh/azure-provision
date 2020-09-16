param (
    [string] $targetEnv='lolcat',
    [string] $resourceGroupName='playground',
    [string] $deployedBy='hk'
)
$ErrorActionPreference = "Stop"


$config = @{
    deployed_by          = $deployedBy
    target_env           = $targetEnv
    stack_resource_group = $resourceGroupName
    databases  = @(
        @{
            resource_group_name = $resourceGroupName
            server_name         =  "$targetEnv-sqlserver"
            database_name       =  "Management"
            policy_weeks        =  1
            display_name        = "Management Database"
        }
    )
}

$currentDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$tfVarsFile = "$currentDir/vars.auto.tfvars.json"
  
Write-Host "Writing config to $tfVarsFile"
$config | ConvertTo-Json | Out-File -Encoding ASCII $tfVarsFile