output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "subnet_agw_id" {
  value = azurerm_subnet.agw.id
}

output "subnet_vnet_int_id" {
  description = "vnet-int-snet (10.0.1.0/25) — delegated for App Service VNet integration (outbound)"
  value       = azurerm_subnet.vnet_int.id
}

output "subnet_pe_id" {
  description = "pe-snet (10.0.1.128/25) — non-delegated, hosts SWA PE and App Service PE"
  value       = azurerm_subnet.pe.id
}

output "subnet_db_id" {
  value = azurerm_subnet.db.id
}

output "subnet_platform_id" {
  value = azurerm_subnet.platform.id
}

output "subnet_firewall_id" {
  value = azurerm_subnet.firewall.id
}

# Application data DNS zones
output "private_dns_zone_cosmos_id" {
  value = azurerm_private_dns_zone.cosmos.id
}

output "private_dns_zone_swa_id" {
  value = azurerm_private_dns_zone.swa.id
}

output "private_dns_zone_appservice_id" {
  value = azurerm_private_dns_zone.appservice.id
}

# Platform DNS zones
output "private_dns_zone_kv_id" {
  value = azurerm_private_dns_zone.kv.id
}

output "private_dns_zone_monitor_id" {
  value = azurerm_private_dns_zone.monitor.id
}

output "private_dns_zone_ods_id" {
  value = azurerm_private_dns_zone.ods.id
}

output "private_dns_zone_oms_id" {
  value = azurerm_private_dns_zone.oms.id
}

output "private_dns_zone_blob_id" {
  value = azurerm_private_dns_zone.blob.id
}

output "private_dns_zone_agentsvc_id" {
  value = azurerm_private_dns_zone.agentsvc.id
}
