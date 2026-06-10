resource "azurerm_static_web_app" "main" {
  name                = var.name_prefix
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_tier            = "Standard"
  sku_size            = "Standard"
  tags                = var.tags
}

# Private endpoint — in pe-snet (non-delegated). vnet-int-snet is delegated and
# cannot host private endpoints; pe-snet holds all app-tier PEs.
resource "azurerm_private_endpoint" "swa" {
  name                = "pe-swa-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.subnet_pe_id

  private_service_connection {
    name                           = "psc-swa-${var.name_prefix}"
    private_connection_resource_id = azurerm_static_web_app.main.id
    subresource_names              = ["staticSites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdns-swa"
    private_dns_zone_ids = [var.private_dns_zone_swa_id]
  }

  tags = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "swa" {
  name                       = "diag-swa"
  target_resource_id         = azurerm_static_web_app.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
