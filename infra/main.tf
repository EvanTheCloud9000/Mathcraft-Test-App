locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_public_ip" "agw" {
  name                = "pip-agw-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.common_tags
}

# ── Networking ────────────────────────────────────────────────────────────────

module "networking" {
  source = "./modules/networking"

  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  vnet_address_space  = var.vnet_address_space
  tags                = local.common_tags
}

# ── Monitoring ────────────────────────────────────────────────────────────────
# Depends on networking for the platform subnet and AMPLS DNS zones.

module "monitoring" {
  source = "./modules/monitoring"

  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_platform_id  = module.networking.subnet_platform_id

  private_dns_zone_monitor_id  = module.networking.private_dns_zone_monitor_id
  private_dns_zone_ods_id      = module.networking.private_dns_zone_ods_id
  private_dns_zone_oms_id      = module.networking.private_dns_zone_oms_id
  private_dns_zone_blob_id     = module.networking.private_dns_zone_blob_id
  private_dns_zone_agentsvc_id = module.networking.private_dns_zone_agentsvc_id

  tags = local.common_tags
}

# ── Firewall ──────────────────────────────────────────────────────────────────

module "firewall" {
  source = "./modules/firewall"

  name_prefix                = local.name_prefix
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  subnet_firewall_id         = module.networking.subnet_firewall_id
  app_subnet_cidr            = cidrsubnet(var.vnet_address_space, 9, 2) # vnet-int-snet 10.0.1.0/25
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  tags                       = local.common_tags
}

# Force all egress from vnet-int-snet through the firewall.
resource "azurerm_subnet_route_table_association" "app_egress" {
  subnet_id      = module.networking.subnet_vnet_int_id
  route_table_id = module.firewall.route_table_id
}

# ── Key Vault ─────────────────────────────────────────────────────────────────

module "key_vault" {
  source = "./modules/key_vault"

  name_prefix                = "kv-${local.name_prefix}-${random_string.suffix.result}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  deployer_object_id         = data.azurerm_client_config.current.object_id
  deployer_ips               = var.deployer_ips
  subnet_platform_id         = module.networking.subnet_platform_id
  private_dns_zone_kv_id     = module.networking.private_dns_zone_kv_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  tags                       = local.common_tags
}

# ── Cosmos DB ─────────────────────────────────────────────────────────────────

module "cosmos" {
  source = "./modules/cosmos"

  name_prefix                = "cosmos-${local.name_prefix}-${random_string.suffix.result}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  subnet_db_id               = module.networking.subnet_db_id
  private_dns_zone_cosmos_id = module.networking.private_dns_zone_cosmos_id
  cosmosdb_throughput        = var.cosmosdb_throughput
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  tags                       = local.common_tags
}

# ── App Service ───────────────────────────────────────────────────────────────

module "app_service" {
  source = "./modules/app_service"

  name_prefix                   = "api-${local.name_prefix}-${random_string.suffix.result}"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  app_service_sku               = var.app_service_sku
  subnet_vnet_int_id             = module.networking.subnet_vnet_int_id
  subnet_pe_id                   = module.networking.subnet_pe_id
  private_dns_zone_appservice_id = module.networking.private_dns_zone_appservice_id
  cosmos_endpoint                = module.cosmos.cosmos_endpoint
  cosmos_db_name                = module.cosmos.database_name
  cosmos_container_name         = module.cosmos.container_name
  key_vault_uri                 = module.key_vault.key_vault_uri
  appinsights_connection_string = module.monitoring.appinsights_connection_string
  log_analytics_workspace_id    = module.monitoring.log_analytics_workspace_id
  package_url                   = "https://${azurerm_storage_account.deploy.name}.blob.core.windows.net/packages/employee-api.zip"
  tags                          = local.common_tags
}

# ── Static Web App ────────────────────────────────────────────────────────────

module "static_web_app" {
  source = "./modules/static_web_app"

  name_prefix                = "swa-${local.name_prefix}-${random_string.suffix.result}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  subnet_pe_id               = module.networking.subnet_pe_id
  private_dns_zone_swa_id    = module.networking.private_dns_zone_swa_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  tags                       = local.common_tags
}

# ── App Gateway ───────────────────────────────────────────────────────────────

module "app_gateway" {
  source = "./modules/app_gateway"

  name_prefix                = local.name_prefix
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  subnet_agw_id              = module.networking.subnet_agw_id
  public_ip_id               = azurerm_public_ip.agw.id
  swa_private_fqdn           = module.static_web_app.private_fqdn
  app_service_fqdn           = module.app_service.default_hostname
  key_vault_id               = module.key_vault.key_vault_id
  agw_cert_secret_id         = module.key_vault.agw_cert_secret_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  tags                       = local.common_tags
}

# ── Deployment storage ────────────────────────────────────────────────────────
# App Service pulls its deployment ZIP from blob storage via private endpoint.
# Deployer uploads from local machine using their public IP allowlisted below.

resource "azurerm_storage_account" "deploy" {
  name                     = "st${replace(local.name_prefix, "-", "")}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  public_network_access_enabled = true

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = [for ip in var.deployer_ips : replace(ip, "/32", "")]
  }

  tags = local.common_tags
}

resource "azurerm_storage_container" "packages" {
  name                  = "packages"
  storage_account_id    = azurerm_storage_account.deploy.id
  container_access_type = "private"
}

resource "azurerm_private_endpoint" "storage" {
  name                = "pe-st-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = module.networking.subnet_platform_id

  private_service_connection {
    name                           = "psc-st-${local.name_prefix}"
    private_connection_resource_id = azurerm_storage_account.deploy.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdns-st"
    private_dns_zone_ids = [module.networking.private_dns_zone_blob_id]
  }

  tags = local.common_tags
}

# ── Cross-module RBAC wiring ──────────────────────────────────────────────────

resource "azurerm_role_assignment" "app_service_storage" {
  scope                = azurerm_storage_account.deploy.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = module.app_service.principal_id
}

resource "azurerm_role_assignment" "deployer_storage" {
  scope                = azurerm_storage_account.deploy.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_cosmosdb_sql_role_assignment" "app_service" {
  resource_group_name = azurerm_resource_group.main.name
  account_name        = module.cosmos.cosmos_account_name
  role_definition_id  = "${module.cosmos.cosmos_account_id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = module.app_service.principal_id
  scope               = module.cosmos.cosmos_account_id
}

resource "azurerm_role_assignment" "app_service_kv" {
  scope                = module.key_vault.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.app_service.principal_id
}

# ── Key Vault secrets ─────────────────────────────────────────────────────────

resource "azurerm_key_vault_secret" "cosmos_endpoint" {
  name         = "cosmos-endpoint"
  value        = module.cosmos.cosmos_endpoint
  key_vault_id = module.key_vault.key_vault_id

  depends_on = [module.key_vault]
}

resource "azurerm_key_vault_secret" "swa_deploy_token" {
  name         = "swa-deployment-token"
  value        = module.static_web_app.api_key
  key_vault_id = module.key_vault.key_vault_id

  depends_on = [module.key_vault]
}
