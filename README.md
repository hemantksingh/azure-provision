# azure-provision

Provision azure paas resources using terraform and deploy apps with azcli

## Build terraform image

`docker build -t hemantksingh/terraform .`

## Run locally

```sh
docker run -e ARM_CLIENT_ID=$AZURE_CLIENT_ID -e ARM_CLIENT_SECRET=$AZURE_CLIENT_SECRET -e ARM_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID -e ARM_TENANT_ID=$AZURE_TENANT_ID -it hemantksingh/terraform /bin/bash

terraform plan -out sec.tfplan
terraform apply "sec.tfplan"
```
