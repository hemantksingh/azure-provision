
variable "subscription_id" {
}

variable "client_id" {
}

variable "client_secret" {
}

variable "tenant_id" {
}

variable "azure_region" {
  type    = string
}

variable "target_env" {
  type    = string
}

variable "stack_resource_group" {
  type    = string
}

variable "deployed_by" {
  type  = string
}

variable "ssh_public_key" {
  type    = string
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDNcw58KR49h5C8xzajfeWP+LL6pAfVev3b+z/QBKFSjqfY7UVYA8OMh/Ioycv2FC0gflVF4uSch+gcaM1UzPhmmzxLI3jwccBLSMwLu4PvQeYSGILAnmiYEhpcxBRhvjcMUJOLA7aVkEDXN1FFPC5GUi70jfPeoqD7fWb4pd0hJVL8cdp3yxtcw49t1lO4YoIk+3n55viCfQzDbZf/brXVNhi+TCTj/v4+uCl13ZT5N5anH2yaEp2pl6ya3XxMmpmPUcRw9KX7WiyCLuHu1pfICssMEjmN+uNhAmA2D/DeI00PpAqS/0PJ0Mk6+dFLjrcMbnTnFrqjiZHu+1z3q1szOdo8PgWv/xJLCBAJEpDaIEMHhWl8mtkJMttm5yIqzJngd2BySO6IJcFgBptWV9als4vaLxIEbpxG9nxI8+uxM3dLKzy/X4V9ynAomn7v4qJeIoS0FCzJKOK+avp5E6SOfkZekWTncxCD2l6FCKP+3hSJzX/abp9qpaAiutS7yqZGP3IpX33pkXWHB8pHFThl4yNbcexaXrLiJVexGr5iBcNCT99zBCKhs/IKgHCGrXwJhh4JeshLPIwIFM+4ElLA9GxFL4weRfTxXZNYxPAxiMPuiXvimptg/LW430A0X8wB7p2cPlRDs7cOOiFOuk2WrUds6hHLOo2fuMCzqpTnuw=="
}

variable "sql_admin_user" {
  type    = string
  default = "sqlUsername"
}

terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  version = "=2.4.0"

  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id

  features {}
}

locals {
  cluster_name = "${var.target_env}-aks"
  cluster_full_name = "${var.azure_region}-${var.target_env}-01"
  common_tags = {
    DeploymentDate  = formatdate("YYYY-MM-DD'T'hh:mm:ssZ", timestamp())
    EnvironmentType = var.target_env
    DeployedBy      = var.deployed_by
  }
}

data "azurerm_client_config" "current" {
}

resource "random_password" "sql_admin_password" {
  length           = 20
  lower            = true
  upper            = true
  number           = true
  special          = true
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!*+._~"
}

resource "azurerm_resource_group" "stack_resource_group" {
  name     = var.stack_resource_group
  location = var.azure_region
}

resource "azurerm_resource_group" "keyvault_resource_group" {
  name     = "${local.cluster_name}-rg-kv"
  location = var.azure_region
  tags     = merge(local.common_tags, { "ResourceGroup" = var.stack_resource_group })
}

resource "azurerm_key_vault" "cluster_kv" {
  name                = "${local.cluster_name}-kv"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.keyvault_resource_group.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "create",
      "get",
    ]

    secret_permissions = [
      "set",
      "list",
      "get",
      "delete",
    ]
  }

  enabled_for_deployment          = true
  enabled_for_template_deployment = true
}

resource "azurerm_key_vault_secret" "sql_admin_user" {
  name         = "sql-admin-user"
  value        = var.sql_admin_user
  key_vault_id = azurerm_key_vault.cluster_kv.id

  tags = {
    environment = local.cluster_name
  }
}

resource "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "sql-admin-password"
  value        = random_password.sql_admin_password.result
  key_vault_id = azurerm_key_vault.cluster_kv.id

  tags = {
    environment = local.cluster_name
  }
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.cluster_name
  kubernetes_version  = "1.17.7"
  location            = azurerm_resource_group.stack_resource_group.location
  resource_group_name = azurerm_resource_group.stack_resource_group.name
  dns_prefix          = "${var.target_env}aks"
  node_resource_group = "mc-${azurerm_resource_group.stack_resource_group.name}-${local.cluster_name}"

  linux_profile {
    admin_username = "hkumar"

    ssh_key {
        key_data = var.ssh_public_key
    }
  }

  network_profile {
    network_plugin = "kubenet"
  }

  default_node_pool {
    name       = "${var.target_env}nodes"
    node_count = 3
    vm_size    = "Standard_D2_v2"
    availability_zones = [1, 2, 3] # By defining node pools in a cluster to span multiple zones, nodes in a given node pool are able to continue operating even if a single zone goes down https://docs.microsoft.com/en-us/azure/aks/availability-zones
  }

  service_principal {
    client_id     = var.client_id
    client_secret = var.client_secret
  }

  tags = {
    environment = var.target_env
  }

  provisioner "local-exec" {
    command = "./neel.sh"
    interpreter = ["/bin/bash", "-e"]

    environment = {
          AZURE_CLIENT_ID       = "${var.client_id}"
          AZURE_CLIENT_SECRET   = "${var.client_secret}"
          AZURE_TENANT_ID       = "${var.tenant_id}"
          AKS_RESOURCE_GROUP    = "${azurerm_kubernetes_cluster.aks.resource_group_name}"
          AKS_CLUSTER_NAME      = "${azurerm_kubernetes_cluster.aks.name}"
    }
  }
}

output "client_certificate" {
  value = azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.aks.kube_config_raw
}