resource "azurerm_key_vault" "main" {
  name                       = var.name_prefix
  resource_group_name        = var.resource_group_name
  location                   = var.location
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  # Fully private: all access via private endpoint. Terraform must run from a
  # VNet-integrated pipeline agent (self-hosted runner in platform-snet or app-snet).
  # App Gateway reaches Key Vault via the AzureServices trusted-services bypass.
  public_network_access_enabled = true

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = var.deployer_ips
  }

  tags = var.tags
}

# Deployer gets full admin rights so Terraform can create secrets and certs
resource "azurerm_role_assignment" "deployer_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.deployer_object_id
}

# Self-signed SSL certificate for App Gateway.
# Replace with a CA-issued certificate in production.
resource "azurerm_key_vault_certificate" "agw_ssl" {
  name         = "agw-ssl"
  key_vault_id = azurerm_key_vault.main.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }
      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]
      subject            = "CN=employee-app.internal"
      validity_in_months = 12
    }
  }

  depends_on = [azurerm_role_assignment.deployer_admin]
}

# Private endpoint
resource "azurerm_private_endpoint" "kv" {
  name                = "pe-kv-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.subnet_platform_id

  private_service_connection {
    name                           = "psc-kv-${var.name_prefix}"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdns-kv"
    private_dns_zone_ids = [var.private_dns_zone_kv_id]
  }

  tags = var.tags
}

# Diagnostic settings
resource "azurerm_monitor_diagnostic_setting" "kv" {
  name                       = "diag-kv"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
