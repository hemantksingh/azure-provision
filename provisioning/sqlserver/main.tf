provider "azurerm" {
  features {}
}

terraform {
  backend "azurerm" {}
}

variable "azure_region" {
    type = string
}

variable "stack_name" {
    type = string
}

variable "sql_admin_user" {
  type    = string
  default = "sqlUsername"
}

resource "random_string" "random_id" {
  length  = 10
  lower   = true
  upper   = false
  number  = false
  special = false
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


locals {
  stack_key_vault       = "${var.stack_name}-kv"
  stack_resource_group  = "${var.azure_region}-${var.stack_name}-aks"
}

data "azurerm_key_vault" "existing" {
    name                = local.stack_key_vault
    resource_group_name = local.stack_resource_group
}

resource "azurerm_key_vault_secret" "sql_admin_user" {
  name         = "sql-admin-user"
  value        = var.sql_admin_user
  key_vault_id = data.azurerm_key_vault.existing.id

  tags = {
    environment = var.stack_name
  }
}

resource "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "sql-admin-password"
  value        = random_password.sql_admin_password.result
  key_vault_id = data.azurerm_key_vault.existing.id

  tags = {
    environment = var.stack_name
  }
}

resource "azurerm_mssql_server" "stack_sql_server" {
  name                         = "${var.stack_name}-sqlserver"
  resource_group_name          = local.stack_resource_group
  location                     = var.azure_region
  version                      = "12.0"
  administrator_login          = var.sql_admin_user
  administrator_login_password = random_password.sql_admin_password.result
  
  tags = {
    environment = var.stack_name
    displayName = "SqlServer"
  }
}

resource "azurerm_storage_account" "audit" {
  name                      = "${var.stack_name}aud${random_string.random_id.result}"
  resource_group_name       = local.stack_resource_group
  location                  = var.azure_region
  enable_https_traffic_only = true
  account_tier              = "Standard"
  account_replication_type  = "LRS"
}

resource "azurerm_mssql_server_extended_auditing_policy" "sql_server_auditing_policy" {
  server_id                               = azurerm_mssql_server.stack_sql_server.id
  storage_endpoint                        = azurerm_storage_account.audit.primary_blob_endpoint
  storage_account_access_key              = azurerm_storage_account.audit.primary_access_key
  storage_account_access_key_is_secondary = false
  retention_in_days                       = 6
}

resource "azurerm_sql_firewall_rule" "sql_firewall" {
  name                = "${azurerm_mssql_server.stack_sql_server.name}-az-rule"
  resource_group_name = local.stack_resource_group
  server_name         = azurerm_mssql_server.stack_sql_server.name

  # Access from Azure services allowed by the sentinel value 0.0.0.0
  # as per https://docs.microsoft.com/en-us/rest/api/sql/firewallrules/createorupdate
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_elasticpool" "sql_server_pool" {
  name                = "${var.stack_name}-sqlserver-epool"
  resource_group_name = local.stack_resource_group
  location            = var.azure_region

  server_name = azurerm_mssql_server.stack_sql_server.name
  max_size_gb = 100

  sku {
    name     = "StandardPool"
    capacity = 100
    tier     = "Standard"
  }

  per_database_settings {
    min_capacity = 0
    max_capacity = 100
  }

  tags = {
    environment = var.stack_name
    displayName = "SqlServerEpool"
  }
}
