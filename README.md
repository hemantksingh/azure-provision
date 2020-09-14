# Azure Provision

Provision azure resources e.g (AKS, VNets) using terraform, azcli and deploy apps to kubernetes using kubectl

## Run in docker
```sh

# Build the docker image
docker build -t hemantksingh/azurepaas .

# Run terraform provision in a container
docker run -e AZURE_CLIENT_ID=$AZURE_CLIENT_ID -e AZURE_CLIENT_SECRET=$AZURE_CLIENT_SECRET -e AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID -e AZURE_TENANT_ID=$AZURE_TENANT_ID -it hemantksingh/terraform /bin/bash

terraform plan \
    -var subscription_id=$AZURE_SUBSCRIPTION_ID \
    -var client_id=$AZURE_CLIENT_ID \
    -var client_secret=$AZURE_CLIENT_SECRET \
    -var tenant_id=$AZURE_TENANT_ID -out aks.tfplan

terraform apply "aks.tfplan"
```

## AKS setup

You can deploy the aks cluster by running the following:

```sh
# Setup the terraform backend using access key https://www.terraform.io/docs/backends/types/azurerm.html
terraform init -backend-config="storage_account_name=hkterraformstore" -backend-config="container_name=cluster-state" -backend-config="key=lolcat.tfstate" -backend-config="access_key=$BACKEND_ACCESS_KEY"

terraform plan -var subscription_id=$AZURE_SUBSCRIPTION_ID -var client_id=$AZURE_CLIENT_ID -var client_secret=$AZURE_CLIENT_SECRET -var tenant_id=$AZURE_TENANT_ID -out aks.tfplan

terraform apply "aks.tfplan"
```

### AKS management

After deploying the cluster you can access the [kubernetes dashboard](https://docs.microsoft.com/en-gb/azure/aks/kubernetes-dashboard) for basic management operations. To setup the kubernetes dashboard, complete the following steps:

1. Ensure you have the latest version of `azcli` and login using `az login`
2. Install `kubectl` if you do not already have it: `az aks install-cli`
3. Get the credentials for your cluster: `az aks get-credentials -g playground -n lolcat-aks`
4. Verify you can connect to the kubernetes cluster `kubectl cluster-info`
5. If you already haven't, enable the kube-dashboard addon for the cluster: `az aks enable-addons --addons kube-dashboard -g playground -n lolcat-aks`
6. Open the kubernetes dashboard: `az aks browse -g playground -n lolcat-aks`. The dashboard ui can fail to load if you are connecting to the cluster with the same name after destroying and re-provisioning it. In order to resolve this:
    * Delete your kube config `rm ~/.kube/config`
    * Worth deleting your kube config cache if you do not require the old cluster connections `rm -rf ~/.kube/cache`
    * Reconnect to the cluster with step 3
    * Clear browser cache and open dashboard with step 5 & 6

### AKS deprovision

```sh
terraform destroy -var subscription_id=$AZURE_SUBSCRIPTION_ID -var client_id=$AZURE_CLIENT_ID -var client_secret=$AZURE_CLIENT_SECRET -var tenant_id=$AZURE_TENANT_ID
```

### Kubernetes configuration

Deploying kubernetes resources uses `kubectl` cli. You can [deploy an ingress controller](./docs/ingress-controller.md) to route external traffic to your applications.


### Deploy application

After deploying an ingress controller, you can deploy applications to the k8 cluster with ingress rules to define routes into your application

`kubectl apply -f https://raw.githubusercontent.com/hemantksingh/identity-server/master/identity-server.yaml`

```sh
# Generate the CA Key and Certificate
$ openssl req -x509 -sha256 -newkey rsa:4096 -keyout ca.key -out ca.crt -days 356 -nodes -subj '/CN=Lolcat Cert Authority'
# Generate the Server Key, and Certificate and Sign with the CA Certificate
$ openssl req -new -newkey rsa:4096 -keyout server.key -out server.csr -nodes -subj  '/CN=lolcat.azure.com/O=aks-ingress'
$ openssl x509 -req -sha256 -days 365 -in server.csr -CA ca.crt -CAkey ca.key -set_serial 01 -out server.crt
```

Create kubernetes secret for TLS certificate

`kubectl create secret generic aks-ingress-int --from-file=tls.crt=server.crt --from-file=tls.key=server.key --from-file=ca.crt=ca.crt`

Deploy ingress rule

`kubectl apply -f ingress/one-way-ingress.yaml`

Test the ingress configuration

`curl -v -k --resolve lolcat.azure.com:443:EXTERNAL_IP https://lolcat.azure.com`
