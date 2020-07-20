resource "random_string" "random_id" {
  length  = 10
  lower   = true
  upper   = false
  number  = false
  special = false
}

resource "azurerm_storage_account" "audit" {
  name                      = "${var.target_env}audit${random_string.random_id.result}"
  resource_group_name       = azurerm_resource_group.stack_resource_group.name
  location                  = var.azure_region
  enable_https_traffic_only = true
  account_tier              = "Standard"
  account_replication_type  = "LRS"
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

resource "azurerm_sql_server" "stack_sql_server" {
  name                         = "${var.target_env}-sqlserver"
  resource_group_name          = azurerm_resource_group.stack_resource_group.name
  location                     = var.azure_region
  version                      = "12.0"
  administrator_login          = var.sql_admin_user
  administrator_login_password = random_password.sql_admin_password.result

  extended_auditing_policy {
    storage_endpoint           = azurerm_storage_account.audit.primary_blob_endpoint
    storage_account_access_key = azurerm_storage_account.audit.primary_access_key
    retention_in_days          = 90
  }

  tags = {
    environment = var.target_env
    displayName = "SqlServer"
  }
}

resource "azurerm_sql_firewall_rule" "sql_firewall" {
  name                = "${azurerm_sql_server.stack_sql_server.name}-az-rule"
  resource_group_name = azurerm_resource_group.stack_resource_group.name
  server_name         = azurerm_sql_server.stack_sql_server.name

  # Access from Azure services allowed by the sentinel value 0.0.0.0
  # as per https://docs.microsoft.com/en-us/rest/api/sql/firewallrules/createorupdate
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_elasticpool" "sql_server_pool" {
  name                = "${var.target_env}-sql-server-epool"
  resource_group_name = azurerm_resource_group.stack_resource_group.name
  location            = var.azure_region

  server_name = azurerm_sql_server.stack_sql_server.name
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
    environment = var.target_env
    displayName = "SqlServerEpool"
  }
}
