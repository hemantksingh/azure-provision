provider "azurerm" {
  features {}
}

terraform {
  backend "azurerm" {}
}

variable "azure_region" {
  type    = string
}

variable "stack_name" {
  type    = string
}

variable "deployed_by" {
  type  = string
}

variable "ssh_public_key" {
  type    = string
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDNcw58KR49h5C8xzajfeWP+LL6pAfVev3b+z/QBKFSjqfY7UVYA8OMh/Ioycv2FC0gflVF4uSch+gcaM1UzPhmmzxLI3jwccBLSMwLu4PvQeYSGILAnmiYEhpcxBRhvjcMUJOLA7aVkEDXN1FFPC5GUi70jfPeoqD7fWb4pd0hJVL8cdp3yxtcw49t1lO4YoIk+3n55viCfQzDbZf/brXVNhi+TCTj/v4+uCl13ZT5N5anH2yaEp2pl6ya3XxMmpmPUcRw9KX7WiyCLuHu1pfICssMEjmN+uNhAmA2D/DeI00PpAqS/0PJ0Mk6+dFLjrcMbnTnFrqjiZHu+1z3q1szOdo8PgWv/xJLCBAJEpDaIEMHhWl8mtkJMttm5yIqzJngd2BySO6IJcFgBptWV9als4vaLxIEbpxG9nxI8+uxM3dLKzy/X4V9ynAomn7v4qJeIoS0FCzJKOK+avp5E6SOfkZekWTncxCD2l6FCKP+3hSJzX/abp9qpaAiutS7yqZGP3IpX33pkXWHB8pHFThl4yNbcexaXrLiJVexGr5iBcNCT99zBCKhs/IKgHCGrXwJhh4JeshLPIwIFM+4ElLA9GxFL4weRfTxXZNYxPAxiMPuiXvimptg/LW430A0X8wB7p2cPlRDs7cOOiFOuk2WrUds6hHLOo2fuMCzqpTnuw=="
}

locals {
  cluster_name          = "${var.stack_name}-aks"
  stack_resource_group  = "${var.azure_region}-${var.stack_name}-aks"
  common_tags = {
    DeploymentDate    = formatdate("YYYY-MM-DD'T'hh:mm:ssZ", timestamp())
    StackName         = var.stack_name
    DeployedBy        = var.deployed_by
  }
}


resource "azurerm_resource_group" "stack_resource_group" {
  name     = local.stack_resource_group
  location = var.azure_region
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.cluster_name
  kubernetes_version  = "1.18.10"
  location            = azurerm_resource_group.stack_resource_group.location
  resource_group_name = azurerm_resource_group.stack_resource_group.name
  dns_prefix          = "${var.stack_name}aks"
  node_resource_group = "mc-${azurerm_resource_group.stack_resource_group.name}"

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
    name       = "${var.stack_name}nodes"
    node_count = 1
    vm_size    = "Standard_D2_v2"
    availability_zones = [1, 2, 3] # By defining node pools in a cluster to span multiple zones, nodes in a given node pool are able to continue operating even if a single zone goes down https://docs.microsoft.com/en-us/azure/aks/availability-zones
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    stack = var.stack_name
  }

  provisioner "local-exec" {
    command = "./neel.sh"
    interpreter = ["/bin/bash", "-e"]

    environment = {
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