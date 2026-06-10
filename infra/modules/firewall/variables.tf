variable "name_prefix" {
  description = "Prefix used for all resource names."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group in which to deploy firewall resources."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "subnet_firewall_id" {
  description = "ID of AzureFirewallSubnet."
  type        = string
}

variable "app_subnet_cidr" {
  description = "CIDR of app-snet; scopes egress application rules to only that source."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for diagnostic settings."
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
