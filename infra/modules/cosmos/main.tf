resource "azurerm_cosmosdb_account" "main" {
  name                = var.name_prefix
  resource_group_name = var.resource_group_name
  location            = var.location
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  # No public access — all traffic must come through the private endpoint
  public_network_access_enabled = false

  # All access via Cosmos DB SQL RBAC (managed identity). Keys are disabled.
  local_authentication_disabled = true

  tags = var.tags
}

resource "azurerm_cosmosdb_sql_database" "main" {
  name                = "employeedb"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
}

resource "azurerm_cosmosdb_sql_container" "employees" {
  name                = "employees"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.main.name
  partition_key_paths = ["/department"]
  throughput          = var.cosmosdb_throughput

  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }
  }
}

# Private endpoint
resource "azurerm_private_endpoint" "cosmos" {
  name                = "pe-cosmos-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.subnet_db_id

  private_service_connection {
    name                           = "psc-cosmos-${var.name_prefix}"
    private_connection_resource_id = azurerm_cosmosdb_account.main.id
    subresource_names              = ["Sql"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdns-cosmos"
    private_dns_zone_ids = [var.private_dns_zone_cosmos_id]
  }

  tags = var.tags
}

# Diagnostic settings
resource "azurerm_monitor_diagnostic_setting" "cosmos" {
  name                       = "diag-cosmos"
  target_resource_id         = azurerm_cosmosdb_account.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "DataPlaneRequests"
  }

  metric {
    category = "Requests"
    enabled  = true
  }
}
