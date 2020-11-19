.PHONY: cluster destroy-cluster sqlserver destroy-sqlserver deploy-tenant delete-tenant build run deploy

TARGET_ENV?=brahma
STACK_NAME=$(TARGET_ENV)
AZURE_REGION?=westeurope

TERRAFORM_DIR=provisioning

define winconfig
	powershell $(TERRAFORM_DIR)/$(1)/tfconfig.ps1 \
			-stackName $(STACK_NAME) \
			-azureRegion $(AZURE_REGION)
endef

define linuxconfig
	pwsh $(TERRAFORM_DIR)/$(1)/tfconfig.ps1 \
		-stackName $(STACK_NAME) \
		-azureRegion $(AZURE_REGION)
endef

# Terraform azure backend config, requires ARM_ACCESS_KEY or SAS token
BACKEND_STORAGE_ACCOUNT?=hkterraformstore
BACKEND_CONTAINER?=experiment

define tfinit
	cd $(TERRAFORM_DIR)/$(1) && terraform init \
		-backend-config="storage_account_name=$(BACKEND_STORAGE_ACCOUNT)" \
		-backend-config="container_name=$(BACKEND_CONTAINER)" \
		-backend-config="key=$(2)"
endef

CLUSTER_KEY=$(AZURE_REGION)-$(STACK_NAME)-aks
cluster:
ifeq ($(OS), Windows_NT)
	$(call winconfig,$@)
else
	$(call linuxconfig,$@)
endif
	$(call tfinit,$@,$(CLUSTER_KEY).tfstate) && \
	terraform plan -out $(CLUSTER_KEY).tfplan
ifeq ($(APPLY), true)
	cd $(TERRAFORM_DIR)/$@ && \
	terraform apply $(CLUSTER_KEY).tfplan
else
	@echo Skipping apply ...
endif

destroy-cluster:
	cd $(TERRAFORM_DIR)/cluster && terraform destroy

SQLSERVER_KEY=$(AZURE_REGION)-$(STACK_NAME)-sql
sqlserver:
	$(call tfinit,$@,$(SQLSERVER_KEY).tfstate) && \
	terraform plan \
		-var stack_name=$(STACK_NAME) \
		-var azure_region=$(AZURE_REGION) \
		-out $(SQLSERVER_KEY).tfplan
ifeq ($(APPLY), true)
	cd $(TERRAFORM_DIR)/$@ && \
	terraform apply $(SQLSERVER_KEY).tfplan
else
	@echo Skipping apply ...
endif

destroy-sqlserver:
	cd $(TERRAFORM_DIR)/sqlserver && terraform destroy \
		-var stack_name=$(STACK_NAME) \
		-var azure_region=$(AZURE_REGION)

TENANT_KEY=$(AZURE_REGION)-$(STACK_NAME)-tenant
tenant:
ifeq ($(OS), Windows_NT)
	$(call winconfig,$@)
else
	$(call linuxconfig,$@)
endif
	$(call tfinit,$@,$(TENANT_KEY).tfstate) && \
	terraform plan -out $(TENANT_KEY).tfplan
ifeq ($(APPLY), true)
	cd $(TERRAFORM_DIR)/$@ && \
	terraform apply $(TENANT_KEY).tfplan
else
	@echo Skipping apply ...
endif

destroy-tenant:
	cd $(TERRAFORM_DIR)/tenant && terraform destroy

stack: cluster sqlserver tenant

destroy-stack: destroy-tenant destroy-sqlserver destroy-cluster

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
