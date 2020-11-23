# AKS and key vault integration

Managed identity is used to get read access to Azure key vault resources from pods running within your AKS cluster. You access and retrieve secrets from your Azure key vault by using the Secrets Store Container Storage Interface (CSI) driver to mount the secrets into Kubernetes pods. The CSI driver is installed into your cluster using helm.

## Requirements

* az cli
* kubectl
* helm

## Configure key vault

The following script encapsulates the steps outlined in [this](https://docs.microsoft.com/en-us/azure/key-vault/general/key-vault-integrate-kubernetes) document. The script assigns the AKS cluster appropriate roles to create, list or read a user-assigned managed identity, creates the managed identity and provide the Azure managed identity read access to the keyvault.

```powershell

./keyvault/configureKeyVault.ps1 `
    -clusterName <clusterName> `
    -tenantName <tenantName> `
    -clusterResourceGroup <clusterResourceGroup> `
    -keyvaultName <keyvaultName>
```

## Run a pod that requires access to secrets

``` powershell

# Run an nginx pod with secrets mounted as volumes
./apps/deployNginx.ps1 -keyvaultName <keyvaultName>

```
## Test pod access to secret content

```sh
# display the mounted secrets mounte in the pod
kubectl exec -it nginx-secrets-store-inline -- ls /mnt/secrets-store/
tenantId

# display the contents of the specific secret
kubectl exec -it nginx-secrets-store-inline -- cat /mnt/secrets-store/tenantId
<tenantid_value>
```