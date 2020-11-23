data "azurerm_client_config" "current" {
}

resource "azurerm_key_vault" "tenant_kv" {
  name                = "${var.app_tenant.name}-kv"
  location            = var.azure_region
  resource_group_name = local.stack_resource_group
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "create",
      "get",
      "list"
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

resource "azurerm_key_vault_secret" "tenant_id" {
  name         = "tenantId"
  value        = var.app_tenant.id
  key_vault_id = azurerm_key_vault.tenant_kv.id

  tags = {
    environment = local.cluster_name
  }
}

resource "azurerm_key_vault_secret" "sql_user" {
  name         = "sql-user"
  value        = var.app_tenant.sql_user
  key_vault_id = azurerm_key_vault.tenant_kv.id

  tags = {
    environment = local.cluster_name
  }
}

resource "azurerm_key_vault_secret" "sql_password" {
  name         = "sql-password"
  value        = var.app_tenant.sql_password
  key_vault_id = azurerm_key_vault.tenant_kv.id

  tags = {
    environment = local.cluster_name
  }
}