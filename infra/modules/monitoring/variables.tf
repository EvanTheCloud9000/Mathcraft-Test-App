variable "name_prefix" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "subnet_platform_id" {
  description = "platform-snet subnet ID — AMPLS private endpoint is placed here"
  type        = string
}

variable "private_dns_zone_monitor_id" {
  type = string
}

variable "private_dns_zone_ods_id" {
  type = string
}

variable "private_dns_zone_oms_id" {
  type = string
}

variable "private_dns_zone_blob_id" {
  type = string
}

variable "private_dns_zone_agentsvc_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
