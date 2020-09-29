.PHONY: plan-cluster deploy-cluster delete-cluster deploy-tenant delete-tenant build run deploy

TARGET_ENV?=lolcat

# Terraform azure backend config, requires ARM_ACCESS_KEY or SAS token
BACKEND_STORAGE_ACCOUNT?=hkterraformstore
BACKEND_CONTAINER?=cluster-state

CLUSTER_DIR=provisioning/cluster
plan-cluster:
	cd $(CLUSTER_DIR) && terraform init \
		-backend-config="storage_account_name=$(BACKEND_STORAGE_ACCOUNT)" \
		-backend-config="container_name=$(BACKEND_CONTAINER)" \
		-backend-config="key=$(TARGET_ENV).tfstate"
	pwsh $(CLUSTER_DIR)/tfconfig.ps1
	cd $(CLUSTER_DIR) && terraform plan \
		-var subscription_id=$(AZURE_SUBSCRIPTION_ID) \
		-var client_id=$(AZURE_CLIENT_ID) \
		-var client_secret=$(AZURE_CLIENT_SECRET) \
		-var tenant_id=$(AZURE_TENANT_ID) \
		-out $(TARGET_ENV)_cluster.tfplan

deploy-cluster:
	cd $(CLUSTER_DIR) && terraform apply "$(TARGET_ENV)_cluster.tfplan"

delete-cluster:
	pwsh $(CLUSTER_DIR)/tfconfig.ps1
	cd $(CLUSTER_DIR) && terraform destroy  \
		-var subscription_id=$(AZURE_SUBSCRIPTION_ID) \
		-var client_id=$(AZURE_CLIENT_ID) \
		-var client_secret=$(AZURE_CLIENT_SECRET) \
		-var tenant_id=$(AZURE_TENANT_ID)

TENANT_DIR=provisioning/tenant
deploy-tenant:
	pwsh $(TENANT_DIR)/tfconfig.ps1
	cd $(TENANT_DIR) && terraform init \
		-backend-config="storage_account_name=$(BACKEND_STORAGE_ACCOUNT)" \
		-backend-config="container_name=$(BACKEND_CONTAINER)" \
		-backend-config="key=$(TARGET_ENV)-$(AZURE_TENANT_ID).tfstate"
	cd $(TENANT_DIR) && terraform plan \
		-var subscription_id=$(AZURE_SUBSCRIPTION_ID) \
		-var client_id=$(AZURE_CLIENT_ID) \
		-var client_secret=$(AZURE_CLIENT_SECRET) \
		-var tenant_id=$(AZURE_TENANT_ID) \
		-out $(TARGET_ENV)_tenant.tfplan
	cd $(TENANT_DIR) && terraform apply "$(TARGET_ENV)_tenant.tfplan"

delete-tenant:
	echo tenant
	cd $(TENANT_DIR) && terraform destroy \
		-var subscription_id=$(AZURE_SUBSCRIPTION_ID) \
		-var client_id=$(AZURE_CLIENT_ID) \
		-var client_secret=$(AZURE_CLIENT_SECRET) \
		-var tenant_id=$(AZURE_TENANT_ID)
	
IMAGE?=hemantksingh/azurepaas
TARGET_ENV?=dev
APP_VERSION?=

build:
	docker build -t $(IMAGE) .

run: build
	docker run --rm \
		-e TARGET_ENV=$(TARGET_ENV) \
		-v ~/.azure:/root/.azure $(IMAGE)

deploy: build
	docker run --rm \
		-e TARGET_ENV=$(TARGET_ENV) \
		-e AZURE_CLIENT_ID=$(AZURE_CLIENT_ID) \
		-e AZURE_CLIENT_SECRET=$(AZURE_CLIENT_SECRET) \
		-e AZURE_TENANT_ID=$(AZURE_TENANT_ID) \
		$(IMAGE) init
