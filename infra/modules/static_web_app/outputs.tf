output "swa_id" {
  value = azurerm_static_web_app.main.id
}

output "default_hostname" {
  value = azurerm_static_web_app.main.default_host_name
}

output "api_key" {
  description = "SWA deployment token — stored in Key Vault as swa-deployment-token"
  value       = azurerm_static_web_app.main.api_key
  sensitive   = true
}

output "private_fqdn" {
  description = "Private endpoint FQDN used by App Gateway as the SWA backend pool address"
  value       = azurerm_private_endpoint.swa.private_dns_zone_configs[0].record_sets[0].fqdn
}
