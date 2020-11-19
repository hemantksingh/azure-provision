param (
    [Parameter(mandatory = $true)][string] $stackName,
    [Parameter(mandatory = $true)][string] $azureRegion,
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


$appTenant = Generate-UniqueTenant 'lol'

$config = @{
    stack_name           = $stackName
    azure_region         = $azureRegion
    deployed_by          = $deployedBy
    app_tenant = @{
        id              = $appTenant.id
        name            = $appTenant.name
        sql_user        = "$($appTenant.name)SqlUser"
        sql_password    = New-RandomPassword -Size 20 -CharSets ULNQ
    }
    databases  = @(
        @{
            server_name         =  "$stackName-sqlserver"
            database_name       =  "Management"
            policy_weeks        =  1
            display_name        = "Management Database"
        }
    )
}

$tfVarsFile = "$currentDir/vars.auto.tfvars.json"
  
Write-Host "Writing config to $tfVarsFile"
$config | ConvertTo-Json | Out-File -Encoding ASCII $tfVarsFile