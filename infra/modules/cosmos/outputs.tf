output "cosmos_account_name" {
  value = azurerm_cosmosdb_account.main.name
}

output "cosmos_account_id" {
  value = azurerm_cosmosdb_account.main.id
}

output "cosmos_endpoint" {
  value = azurerm_cosmosdb_account.main.endpoint
}

output "database_name" {
  value = azurerm_cosmosdb_sql_database.main.name
}

output "container_name" {
  value = azurerm_cosmosdb_sql_container.employees.name
}
