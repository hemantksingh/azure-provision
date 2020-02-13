# azure-provision

Provision azure paas resources using terraform and deploy apps with azcli

## Build terraform image

`docker build -t hemantksingh/terraform .`

## Run locally

```sh
docker run -it hemantksingh/terraform /bin/bash

az login
terraform plan -out sec.tfplan
terraform apply "sec.tfplan"
```
