variable "env" {
  type    = string
  default = "lolcat"
}

variable "ssh_public_key" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

variable "client_id" {
}

variable "client_secret" {
}

provider "azurerm" {
  version = "=2.4.0"
  features {}
}

resource "azurerm_resource_group" "playground" {
  name     = "playground"
  location = "West Europe"
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.env}-aks"
  location            = azurerm_resource_group.playground.location
  resource_group_name = azurerm_resource_group.playground.name
  dns_prefix          = "${var.env}aks"

  linux_profile {
    admin_username = "hkumar"

    ssh_key {
        key_data = file(var.ssh_public_key)
    }
  }

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  service_principal {
    client_id     = var.client_id
    client_secret = var.client_secret
  }

  tags = {
    Environment = var.env
  }
}

output "client_certificate" {
  value = azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.aks.kube_config_raw
}