output "route_table_id" {
  description = "ID of the route table that forces app-snet egress through the firewall."
  value       = azurerm_route_table.app_egress.id
}

output "firewall_private_ip" {
  description = "Private IP of the firewall; used as the next-hop in the route table."
  value       = azurerm_firewall.main.ip_configuration[0].private_ip_address
}
