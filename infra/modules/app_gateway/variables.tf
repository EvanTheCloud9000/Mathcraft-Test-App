variable "name_prefix" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "subnet_agw_id" {
  type = string
}

variable "public_ip_id" {
  description = "Pre-created Standard static public IP resource ID"
  type        = string
}

variable "swa_private_fqdn" {
  description = "SWA private endpoint FQDN — resolved via private DNS to the PE IP in snet-app"
  type        = string
}

variable "app_service_fqdn" {
  description = "App Service default hostname (azurewebsites.net) for the API backend pool"
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault resource ID — used to scope the Key Vault Secrets User role assignment in root"
  type        = string
}

variable "agw_cert_secret_id" {
  description = "Versionless Key Vault secret ID for the AGW SSL certificate"
  type        = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
