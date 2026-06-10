output "app_service_name" {
  value = azurerm_linux_web_app.main.name
}

output "app_service_id" {
  value = azurerm_linux_web_app.main.id
}

output "default_hostname" {
  value = azurerm_linux_web_app.main.default_hostname
}

output "principal_id" {
  description = "User-assigned managed identity principal ID"
  value       = azurerm_user_assigned_identity.app_service.principal_id
}
