output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "app_gateway_public_ip" {
  description = "Public IP of the Application Gateway — use this to access the application"
  value       = azurerm_public_ip.agw.ip_address
}

output "app_service_name" {
  description = "App Service name — used for zip deploy"
  value       = module.app_service.app_service_name
}

output "app_service_default_hostname" {
  description = "App Service hostname (resolves to private endpoint IP within the VNet)"
  value       = module.app_service.default_hostname
}

output "swa_default_hostname" {
  description = "Static Web App hostname"
  value       = module.static_web_app.default_hostname
}

output "cosmos_endpoint" {
  description = "Cosmos DB endpoint (also stored in Key Vault secret cosmos-endpoint)"
  value       = module.cosmos.cosmos_endpoint
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = module.key_vault.key_vault_uri
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace resource ID"
  value       = module.monitoring.log_analytics_workspace_id
}

output "storage_account_name" {
  description = "Deployment storage account name — upload employee-api.zip to the packages container"
  value       = azurerm_storage_account.deploy.name
}
