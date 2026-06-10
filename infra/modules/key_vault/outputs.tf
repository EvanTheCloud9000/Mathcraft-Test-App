output "key_vault_id" {
  value = azurerm_key_vault.main.id
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}

output "agw_cert_secret_id" {
  description = "Versionless secret ID of the AGW SSL certificate — used by App Gateway ssl_certificate block"
  value       = "${azurerm_key_vault.main.vault_uri}secrets/${azurerm_key_vault_certificate.agw_ssl.name}"
}
