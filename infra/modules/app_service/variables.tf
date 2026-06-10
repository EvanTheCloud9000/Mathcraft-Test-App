variable "name_prefix" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "app_service_sku" {
  type    = string
  default = "P1v3"
}

variable "subnet_vnet_int_id" {
  description = "vnet-int-snet subnet ID — App Service regional VNet integration (outbound)"
  type        = string
}

variable "subnet_pe_id" {
  description = "pe-snet subnet ID — App Service private endpoint (inbound from App Gateway)"
  type        = string
}

variable "private_dns_zone_appservice_id" {
  description = "Private DNS zone ID for privatelink.azurewebsites.net"
  type        = string
}

variable "cosmos_endpoint" {
  type = string
}

variable "cosmos_db_name" {
  type = string
}

variable "cosmos_container_name" {
  type = string
}

variable "key_vault_uri" {
  type = string
}

variable "appinsights_connection_string" {
  type      = string
  sensitive = true
}

variable "package_url" {
  description = "Blob Storage URL for WEBSITE_RUN_FROM_PACKAGE — App Service pulls the ZIP via private endpoint using its managed identity"
  type        = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
