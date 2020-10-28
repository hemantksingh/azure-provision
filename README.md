Provision AKS (Azure Kubernetes Service) cluster using `terraform`, `az` cli and deploy apps to kubernetes using `kubectl`

## Provision resources

```sh
# Initialise terraform backend using access key https://www.terraform.io/docs/backends/types/azurerm.html
BACKEND_STORAGE_ACCOUNT=xxxx
BACKEND_CONTAINER=xxxx
ARM_ACCESS_KEY=xxxx

# Make terraform plan
AZURE_SUBSCRIPTION_ID=xxxx
AZURE_CLIENT_ID=xxxx
AZURE_CLIENT_SECRET=xxxx
AZURE_TENANT_ID=xxxx
make plan-cluster

# Provision resources
make deploy-cluster

# Deprovision resources
make delete-cluster
```

### Run provision resources in a container

```sh
# Build the docker image
docker build -t hemantksingh/azurepaas .

# Run terraform provision
docker run -e AZURE_CLIENT_ID=$AZURE_CLIENT_ID -e AZURE_CLIENT_SECRET=$AZURE_CLIENT_SECRET -e AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID -e AZURE_TENANT_ID=$AZURE_TENANT_ID -it hemantksingh/terraform /bin/bash
```

## AKS management

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

## Kubernetes configuration

Deploying kubernetes resources uses `kubectl` cli. You can [deploy an ingress controller](./docs/ingress-controller.md) to route external traffic to your applications.

### Deploy application

After deploying an ingress controller, you can deploy applications to the k8 cluster with ingress rules to define routes into your application

`kubectl apply -f https://raw.githubusercontent.com/hemantksingh/identity-server/master/identity-server.yaml`


### Generate certificates

```sh

# Generate the CA Key and Certificate
$ openssl req -x509 -sha256 -newkey rsa:4096 -days 356 -nodes \
	-keyout ca.key \
	-out ca.crt \
	-subj '/CN=Internal Cert Authority/O=CA Org/C=GB'

# Generate the Server Key and Server Certificate and Sign with the CA Certificate
$ openssl req -new -nodes -newkey rsa:4096 \
	-out server.csr \
	-keyout server.key \
	-subj '/CN={EXTERNAL_IP}.nip.io/O=aks-ingress/C=GB'
$ openssl x509 -req -sha256 -days 365 \
	-in server.csr \
	-CA ca.crt -CAkey ca.key \
	-set_serial 01 \
	-out server.crt

# Generate the Client Key and client Certificate and Sign with the CA Certificate
$ openssl req -new -nodes -newkey rsa:4096 \
	-out client.csr \
	-keyout client.key \
	-subj '/CN=local-client/O=aks-ingress-client/C=GB'
$ openssl x509 -req -sha256 -days 365 \
	-in client.csr \
	-CA ca.crt -CAkey ca.key \
	-set_serial 02 \
	-out client.crt
```

### Create kubernetes secrets

```sh
# Using same CA for both client and server cert validation
kubectl create secret generic aks-ingress-int --from-file=tls.crt=server.crt --from-file=tls.key=server.key --from-file=ca.crt=ca.crt


# Using different CAs for client cert validation and server TLS

# Add a secret for cert validation (e.g. issued by an internal CA)
kubectl create secret generic local-ca --from-file=ca.crt=local-ca.crt

# Add a secret for server TLS (e.g. issued by a global CA)
kubectl create secret tls trusted-tls --key trusted-server.key --cert trusted-server.crt
```

### Configure ingress rule

`kubectl apply -f ingress/one-way-ingress.yaml`

Test the ingress configuration

`curl -v -k https://{EXTERNAL_IP}.nip.io`

Test the ingress configuration for cert based authentication

`curl -v -k https://{EXTERNAL_IP}.nip.io --cert local-client.crt --key local-client.key`
