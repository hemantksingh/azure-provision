tfdestroy:
.PHONY: tfinit tfplan tfapply tfdestroy

TARGET_ENV?=lolcat

# Terraform azure backend config, requires ARM_ACCESS_KEY or SAS token
BACKEND_STORAGE_ACCOUNT?=hkterraformstore
BACKEND_CONTAINER?=cluster-state
BACKEND_CONFIG_KEY=$(TARGET_ENV).tfstate


tfinit:
	terraform init \
		-backend-config="storage_account_name=$(BACKEND_STORAGE_ACCOUNT)" \
		-backend-config="container_name=$(BACKEND_CONTAINER)" \
		-backend-config="key=$(BACKEND_CONFIG_KEY)"

tfplan:
	terraform plan \
		-var subscription_id=$(AZURE_SUBSCRIPTION_ID) \
		-var client_id=$(AZURE_CLIENT_ID) \
		-var client_secret=$(AZURE_CLIENT_SECRET) \
		-var tenant_id=$(AZURE_TENANT_ID) \
		-out $(TARGET_ENV).tfplan

tfapply:
	terraform apply "$(TARGET_ENV).tfplan"


tfdestroy:
	terraform destroy  \
		-var subscription_id=$(AZURE_SUBSCRIPTION_ID) \
		-var client_id=$(AZURE_CLIENT_ID) \
		-var client_secret=$(AZURE_CLIENT_SECRET) \
		-var tenant_id=$(AZURE_TENANT_ID)