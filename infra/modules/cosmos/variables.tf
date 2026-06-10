variable "name_prefix" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "subnet_db_id" {
  description = "ID of db-snet — Cosmos DB private endpoint is placed here."
  type        = string
}

variable "private_dns_zone_cosmos_id" {
  type = string
}

variable "cosmosdb_throughput" {
  type    = number
  default = 400
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
