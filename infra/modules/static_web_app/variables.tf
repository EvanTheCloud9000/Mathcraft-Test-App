variable "name_prefix" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "subnet_pe_id" {
  description = "pe-snet subnet ID — SWA private endpoint (non-delegated)"
  type        = string
}

variable "private_dns_zone_swa_id" {
  description = "Private DNS zone ID for privatelink.azurestaticapps.net"
  type        = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
