variable "project_name" {
  description = "Short project name used in resource naming (max 8 chars, lowercase)"
  type        = string
  default     = "empapp"

  validation {
    condition     = length(var.project_name) <= 8 && can(regex("^[a-z0-9]+$", var.project_name))
    error_message = "project_name must be lowercase alphanumeric and 8 characters or fewer."
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "australiaeast"
}

variable "vnet_address_space" {
  description = "VNet CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "app_service_sku" {
  description = "App Service Plan SKU — must be P1v3 or higher for VNet integration"
  type        = string
  default     = "P1v3"
}

variable "cosmosdb_throughput" {
  description = "Provisioned RU/s for the employees container"
  type        = number
  default     = 400
}

variable "deployer_ips" {
  description = "Your public IP in CIDR notation — Key Vault allows Terraform to manage secrets from here. Example: [\"1.2.3.4/32\"]"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags applied to every resource"
  type        = map(string)
  default     = {}
}
