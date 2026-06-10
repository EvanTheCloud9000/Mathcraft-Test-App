variable "name_prefix" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "deployer_object_id" {
  description = "Object ID of the identity running Terraform (gets Key Vault Administrator)"
  type        = string
}

variable "deployer_ips" {
  description = "Public IP ranges allowed to reach Key Vault for Terraform management"
  type        = list(string)
  default     = []
}

variable "subnet_platform_id" {
  description = "platform-snet subnet ID — Key Vault private endpoint is placed here"
  type        = string
}

variable "private_dns_zone_kv_id" {
  description = "Private DNS zone ID for privatelink.vaultcore.azure.net"
  type        = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
