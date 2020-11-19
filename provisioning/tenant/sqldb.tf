terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

variable "stack_name" {
  type    = string
}

variable "azure_region" {
  type    = string
}

variable "deployed_by" {
  type  = string
}

variable "app_tenant" {
  type = object({
    id            = string
    name          = string
    sql_user      = string
    sql_password  = string
  })
}

variable "databases" {
  type = list(object({
    server_name         = string
    database_name       = string
    policy_weeks        = number
    display_name        = string
  }))
}

locals {
  cluster_name          = "${var.stack_name}-aks"
  stack_resource_group  = "${var.azure_region}-${var.stack_name}-aks"
  sql_server_name       = "${var.stack_name}-sqlserver"
  sql_server_epool_name = "${var.stack_name}-sqlserver-epool"
  common_tags = {
    DeploymentDate  = formatdate("DD/MM/YYYY hh:mm:ss ZZZ", timestamp())
    StackName       = var.stack_name
    DeployedBy      = var.deployed_by
  }
}

data "azurerm_sql_server" "stack_sql_server" {
  name                = local.sql_server_name
  resource_group_name = local.stack_resource_group
}

data "azurerm_mssql_elasticpool" "sql_server_epool" {
  name                = local.sql_server_epool_name
  server_name         = data.azurerm_sql_server.stack_sql_server.name
  resource_group_name = local.stack_resource_group
}

resource "azurerm_mssql_database" "sqldb" {
  count           = length(var.databases)
  name            = var.databases[count.index].database_name
  server_id       = data.azurerm_sql_server.stack_sql_server.id
  elastic_pool_id = data.azurerm_mssql_elasticpool.sql_server_epool.id
  collation       = "SQL_Latin1_General_CP1_CI_AS"
  sku_name        = "ElasticPool"
  tags = {
    displayName = var.databases[count.index].display_name
  }
}

resource "azurerm_template_deployment" "sql_ltr_policy" {
  depends_on          = [azurerm_mssql_database.sqldb]
  count               = length(var.databases)
  resource_group_name = local.stack_resource_group
  name                = "ltr-policy${var.databases[count.index].database_name}"
  deployment_mode     = "incremental"
  template_body       = <<DEPLOY
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
      "contentVersion": "1.0.0.0",
      "resources": [
        {
          "apiVersion" : "2017-03-01-preview",
          "type" : "Microsoft.Sql/servers/databases/backupLongTermRetentionPolicies",
          "name" : "${var.databases[count.index].server_name}/${var.databases[count.index].database_name}/default",
          "properties" : {
            "weeklyRetention": "P${var.databases[count.index].policy_weeks}W"
          }
        }]
    }
    DEPLOY
}