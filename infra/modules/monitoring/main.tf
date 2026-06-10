resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "main" {
  name                = "appi-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = var.tags
}

# ── Azure Monitor Private Link Scope ──────────────────────────────────────────
# Groups Log Analytics and App Insights under a single private endpoint so all
# monitoring traffic stays on the private network.

resource "azurerm_monitor_private_link_scope" "main" {
  name                = "ampls-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_monitor_private_link_scoped_service" "law" {
  name                = "psvc-law-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  scope_name          = azurerm_monitor_private_link_scope.main.name
  linked_resource_id  = azurerm_log_analytics_workspace.main.id
}

resource "azurerm_monitor_private_link_scoped_service" "appi" {
  name                = "psvc-appi-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  scope_name          = azurerm_monitor_private_link_scope.main.name
  linked_resource_id  = azurerm_application_insights.main.id
}

resource "azurerm_private_endpoint" "ampls" {
  name                = "pe-ampls-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.subnet_platform_id

  private_service_connection {
    name                           = "psc-ampls-${var.name_prefix}"
    private_connection_resource_id = azurerm_monitor_private_link_scope.main.id
    subresource_names              = ["azuremonitor"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "pdns-ampls"
    private_dns_zone_ids = [
      var.private_dns_zone_monitor_id,
      var.private_dns_zone_ods_id,
      var.private_dns_zone_oms_id,
      var.private_dns_zone_blob_id,
      var.private_dns_zone_agentsvc_id,
    ]
  }

  # Scoped services must be registered before the PE is provisioned
  depends_on = [
    azurerm_monitor_private_link_scoped_service.law,
    azurerm_monitor_private_link_scoped_service.appi,
  ]

  tags = var.tags
}
