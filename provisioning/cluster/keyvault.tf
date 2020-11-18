data "azurerm_client_config" "current" {
}

resource "azurerm_key_vault" "stack_kv" {
  name                = "${var.stack_name}-kv"
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