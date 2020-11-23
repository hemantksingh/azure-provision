param (
    [Parameter(mandatory = $true)][string] $clusterName,
    [Parameter(mandatory = $true)][string] $clusterResourceGroup,
    [Parameter(mandatory = $true)][string] $keyvaultName,
    [string] $baseDir = '.\provisioning\cluster'
)

$ErrorActionPreference = "Stop"

function Get-AKSCluster(
    [Parameter(mandatory = $true)][string] $clusterName,
    [Parameter(mandatory = $true)][string] $clusterResourceGroup) {
        Write-Host "Geting AKS cluster details for '$clusterName' in resource group '$clusterResourceGroup' ..."   
        $clusterInfo = az aks show -n $clusterName -g $clusterResourceGroup | ConvertFrom-Json
        
        return @{
            name              = $clusterName
            resourceGroup     = $clusterResourceGroup
            principalId       = $clusterInfo.identity.principalId
            clientId          = $clusterInfo.identityProfile.kubeletIdentity.clientId
            nodeResourceGroup = $clusterInfo.nodeResourceGroup
            subscriptionId    = $clusterInfo.id.Split('/')[2]
        }
}

function Get-KeyVault([Parameter(mandatory = $true)][string] $vaultName) {
    Write-Host "Geting details for vault '$vaultName' ..."
    $vault = az keyvault show -n $vaultName | ConvertFrom-Json
    
    return @{
        name = $vaultName
        resourceGroup = $vault.resourceGroup
        subscriptionId = $vault.id.Split('/')[2]
        tenantId = $vault.properties.tenantId
    }    
}

function Add-MangedIdentity(
    [Parameter(mandatory = $true)][string] $identityName,
    [Parameter(mandatory = $true)][string] $resourceGroup) {

        Write-Host "Creating Azure managed identity '$identityName' in resource group '$resourceGroup'"
        az identity create -n $identityName -g $resourceGroup 
        
        $attempts = 0
        $maxAttempts = 5
        $secondsToWait = 5

        do {
            $remaining = $maxAttempts - $attempts
            Write-Host "Waiting $secondsToWait seconds for Azure managed identity '$identityName' to be created. Number of attempts remaining - $remaining"
            Start-Sleep -s $secondsToWait
            $identity = az identity show -n $identityName -g $resourceGroup | ConvertFrom-Json
            $attempts++
        } while ($null -eq $identity -and $attempts -lt $maxAttempts)

        return $identity
}

function Add-DirIfDoesNotExist( [Parameter(Mandatory = $true)][string] $dir) {
    if (!(test-path $dir)) {
        Write-Host "Creating dir '$dir'"
        New-Item -ItemType Directory -Force -Path $dir
    }
    else {
        Write-Host "Directory '$dir' already exists, removing its contents"
        Remove-Item -Path "$dir\*" -Recurse
    }
}

$cluster = Get-AKSCluster $clusterName $clusterResourceGroup
$vault = Get-KeyVault $keyvaultName

Write-Host "Assign AKS cluster '$($cluster.name)' appropriate roles to create, list or read a user-assigned managed identity"
az role assignment create `
    --role "Managed Identity Operator" `
    --assignee $cluster.clientId `
    --scope "/subscriptions/$($cluster.subscriptionId)/resourcegroups/$($cluster.resourceGroup)"

az role assignment create `
    --role "Virtual Machine Contributor" `
    --assignee $cluster.clientId `
    --scope "/subscriptions/$($cluster.subscriptionId)/resourcegroups/$($cluster.resourceGroup)"

az role assignment create `
    --role "Managed Identity Operator" `
    --assignee $cluster.clientId `
    --scope "/subscriptions/$($cluster.subscriptionId)/resourcegroups/$($cluster.nodeResourceGroup)"

az role assignment create `
    --role "Virtual Machine Contributor" `
    --assignee $cluster.clientId `
    --scope "/subscriptions/$($cluster.subscriptionId)/resourcegroups/$($cluster.nodeResourceGroup)"

$managedIdentity = Add-MangedIdentity "$keyvaultName-identity" $clusterResourceGroup

Write-Host "Providing Azure managed identity '$($managedIdentity.name)' read access to the keyvault '$($vault.name)'"
az keyvault set-policy -n $vault.name --secret-permissions get --spn $managedIdentity.clientId
if ($lastexitcode -ne 0) {
    throw "Azure managed identity '$($managedIdentity.name)' with clientId '$($managedIdentity.clientId)'is taking longer than expected to be registered! Please retry!"
}

az keyvault set-policy -n $vault.name --key-permissions get --spn $managedIdentity.clientId
az keyvault set-policy -n $vault.name --certificate-permissions get --spn $managedIdentity.clientId
az role assignment create `
    --role "Reader" `
    --assignee $managedIdentity.principalId `
    --scope "/subscriptions/$($vault.subscriptionId)/resourceGroups/$($vault.resourceGroup)/providers/Microsoft.KeyVault/vaults/$($vault.name)"

$templates = "$((Get-Item -Path "$baseDir/keyvault" -Verbose).FullName)/templates"
$manifests = "$((Get-Item -Path "$baseDir/keyvault" -Verbose).FullName)/manifests"
Add-DirIfDoesNotExist $manifests

Write-Host "Transforming '$templates\secret-provider.yaml' ..."
(Get-Content "$templates\secret-provider.yaml") `
    -replace "{{ keyvault_name }}" ,            $vault.name `
    -replace "{{ keyvault_resource_group }}",   $vault.resourceGroup `
    -replace "{{ keyvault_subscriptionId }}",   $vault.subscriptionId `
    -replace "{{ keyvault_tenantId }}",         $vault.tenantId |
    Set-Content "$manifests\secret-provider.yaml"

Write-Host "Transforming '$templates\pod-identity.yaml' ..."
(Get-Content "$templates\pod-identity.yaml") `
-replace "{{ azure_managed_identity }}" ,               $managedIdentity.name `
    -replace "{{ azure_managed_identity_id }}",         $managedIdentity.id `
    -replace "{{ azure_managed_identity_clientId }}",   $managedIdentity.clientId |
    Set-Content "$manifests\pod-identity.yaml"


function HelmChart-Installed ([Parameter(Mandatory = $true)][string] $chartName) {
    
    $installedChart = helm list | ConvertFrom-CSV | ForEach-Object { 
        $_.psobject.properties | where-object { 
            $_.Value.Equals($chartName)
        } 
    }

    return ![string]::IsNullOrWhiteSpace($installedChart)
}

helm repo add csi-secrets-store-provider-azure https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/master/charts
helm repo add aad-pod-identity https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts


if ((HelmChart-Installed 'csi-secrets-store-provider')) {
    Write-Warning "Helm chart 'csi-secrets-store-provider' already installed, skipping installation ..."
} else {
    helm install csi-secrets-store-provider csi-secrets-store-provider-azure/csi-secrets-store-provider-azure
}
 
if ((HelmChart-Installed 'pod-identity')) {
    Write-Warning "Helm chart 'aad-pod-identity' already installed, skipping installation ..."
} else  {
    helm install pod-identity aad-pod-identity/aad-pod-identity
}

kubectl apply -f $manifests/secret-provider.yaml
kubectl apply -f $manifests/pod-identity.yaml