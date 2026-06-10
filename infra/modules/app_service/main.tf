resource "azurerm_user_assigned_identity" "app_service" {
  name                = "id-app-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_service_plan" "main" {
  name                = "asp-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = var.app_service_sku
  tags                = var.tags
}

resource "azurerm_linux_web_app" "main" {
  name                          = var.name_prefix
  resource_group_name           = var.resource_group_name
  location                      = var.location
  service_plan_id               = azurerm_service_plan.main.id
  https_only                      = true
  virtual_network_subnet_id       = var.subnet_vnet_int_id
  public_network_access_enabled   = false
  key_vault_reference_identity_id = azurerm_user_assigned_identity.app_service.id

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app_service.id]
  }

  site_config {
    always_on              = true
    use_32_bit_worker      = false
    vnet_route_all_enabled = true

    application_stack {
      node_version = "22-lts"
    }

    cors {
      allowed_origins = ["*"]
    }
  }

  app_settings = {
    # Route all DNS through Azure DNS to resolve private DNS zones
    "WEBSITE_DNS_SERVER" = "168.63.129.16"

    # Tell DefaultAzureCredential which user-assigned identity to use
    "AZURE_CLIENT_ID" = azurerm_user_assigned_identity.app_service.client_id

    # Cosmos DB — endpoint from Key Vault, database and container as plain settings
    "COSMOS_ENDPOINT"  = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/cosmos-endpoint/)"
    "COSMOS_DATABASE"  = var.cosmos_db_name
    "COSMOS_CONTAINER" = var.cosmos_container_name

    # Application Insights
    "APPLICATIONINSIGHTS_CONNECTION_STRING"      = var.appinsights_connection_string
    "ApplicationInsightsAgent_EXTENSION_VERSION" = "~3"
    "XDT_MicrosoftApplicationInsights_NodeJS"    = "1"

    "NODE_ENV" = "production"
    "PORT"     = "8080"

    # Pull deployment package from blob storage via private endpoint using the managed identity
    "WEBSITE_RUN_FROM_PACKAGE" = var.package_url
  }

  logs {
    application_logs {
      file_system_level = "Information"
    }
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }

  tags = var.tags
}

# Private endpoint — all inbound traffic to App Service arrives here.
# App Gateway resolves <name>.azurewebsites.net within the VNet; the
# privatelink.azurewebsites.net DNS zone returns the PE private IP.
resource "azurerm_private_endpoint" "app_service" {
  name                = "pe-app-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.subnet_pe_id

  private_service_connection {
    name                           = "psc-app-${var.name_prefix}"
    private_connection_resource_id = azurerm_linux_web_app.main.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdns-app"
    private_dns_zone_ids = [var.private_dns_zone_appservice_id]
  }

  tags = var.tags
}

# Diagnostic settings
resource "azurerm_monitor_diagnostic_setting" "app_service" {
  name                       = "diag-app-service"
  target_resource_id         = azurerm_linux_web_app.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AppServiceHTTPLogs"
  }

  enabled_log {
    category = "AppServiceConsoleLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
