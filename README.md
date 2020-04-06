# Azure Provision

Provision azure resources e.g (AKS, VNets) using terraform and deploy apps with azcli

## Run in docker
```sh

# Build the docker image
docker build -t hemantksingh/terraform .

# Run terraform provision in a container
docker run -e ARM_CLIENT_ID=$AZURE_CLIENT_ID -e ARM_CLIENT_SECRET=$AZURE_CLIENT_SECRET -e ARM_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID -e ARM_TENANT_ID=$AZURE_TENANT_ID -it hemantksingh/terraform /bin/bash

terraform plan -out sec.tfplan
terraform apply "sec.tfplan"
```

## AKS setup

You can deploy the aks cluster by running the following:

```sh
terraform init
terraform plan -var client_id=$AZURE_CLIENT_ID -var client_secret=$AZURE_CLIENT_SECRET -out aks.tfplan
terraform apply "aks.tfplan"
```

### AKS management

After deploying the cluster you can access the [kubernetes dashboard](https://docs.microsoft.com/en-gb/azure/aks/kubernetes-dashboard) for basic management operations. To setup the kubernetes dashboard, complete the following steps:

1. Ensure you have the latest version of `azcli`
2. If you do not already have `kubectl` installed in your CLI, run the following command: `az aks install-cli`
3. Get the credentials for your cluster by running the following command: `az aks get-credentials -g playground -n cluster-aks`
4. Enable the kube dashboard addon `az aks enable-addons --addons kube-dashboard -g playground -n cluster-aks`
5. Open the Kubernetes dashboard by running the following command: `az aks browse -g playground -n cluster-aks`

### AKS deprovision

```sh
terraform destroy -var client_id=$AZURE_CLIENT_ID -var client_secret=$AZURE_CLIENT_SECRET
```
