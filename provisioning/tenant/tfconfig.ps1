param (
    [string] $targetEnv='lolcat',
    [string] $tenantName='lol',
    [string] $azureRegion='westeurope',
    [string] $resourceGroupName='playground',
    [string] $deployedBy='hk'
    )
    $ErrorActionPreference = "Stop"
    
$currentDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
Import-Module $currentDir/password.psm1 -Force;

function Generate-UniqueTenant (
    [Parameter(mandatory = $true)][string] $tenantName,
    [string] $tenantId){
    
    if ([string]::IsNullOrEmpty($tenantId)){ 
      Write-Host 'No tenantId provided, generating a new one...'
      $tenantId = (New-Guid).Guid
      return @{
          id = $tenantId
          name = "$tenantName" + $($tenantId.Substring(0,8))
      }
    }

    Write-Host 'Using the given tenantId'
    return @{
        id = $tenantId
        name = "$tenantName$($tenantId.Substring(0,8))"
    }
}


$appTenant = Generate-UniqueTenant $tenantName

$config = @{
    deployed_by          = $deployedBy
    target_env           = $targetEnv
    azure_region         = $azureRegion
    stack_resource_group = $resourceGroupName
    app_tenant = @{
        id              = $appTenant.id
        name            = $appTenant.name
        sql_user        = "$($appTenant.name)SqlUser"
        sql_password    = New-RandomPassword -Size 20 -CharSets ULNQ
    }
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

$tfVarsFile = "$currentDir/vars.auto.tfvars.json"
  
Write-Host "Writing config to $tfVarsFile"
$config | ConvertTo-Json | Out-File -Encoding ASCII $tfVarsFile