resource "azurerm_resource_group" "playground" {
  name     = "playground"
  location = "West Europe"
}

resource "azurerm_eventhub_namespace" "initial" {
  name                = "initial"
  location            = azurerm_resource_group.playground.location
  resource_group_name = azurerm_resource_group.playground.name
  sku                 = "Standard"
  capacity            = 1

  tags = {
    environment = "dev"
  }
}

resource "azurerm_eventhub" "dev-eventhub" {
  name                = "dev-eventhub"
  namespace_name      = azurerm_eventhub_namespace.initial.name
  resource_group_name = azurerm_resource_group.playground.name
  partition_count     = 2
  message_retention   = 1
}