# User-assigned managed identity so App Gateway can pull the SSL cert from Key Vault
resource "azurerm_user_assigned_identity" "agw" {
  name                = "id-agw-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# Grant Key Vault Secrets User before provisioning the gateway. Azure validates
# KV cert access at AGW creation time, so the role must exist first.
resource "azurerm_role_assignment" "kv_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.agw.principal_id
}

locals {
  frontend_ip_name       = "frontend-ip"
  frontend_port_http     = "port-80"
  frontend_port_https    = "port-443"
  listener_http          = "listener-http"
  listener_https         = "listener-https"
  redirect_to_https      = "redirect-to-https"
  backend_pool_swa       = "backend-swa"
  backend_pool_api       = "backend-api"
  http_settings_swa      = "settings-swa"
  http_settings_api      = "settings-api"
  probe_swa              = "probe-swa"
  probe_api              = "probe-api"
  url_path_map           = "url-path-map"
  ssl_cert_name          = "agw-ssl"
}

resource "azurerm_application_gateway" "main" {
  name                = "agw-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.agw.id]
  }

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
  }

  # WAF policy is attached separately for more granular control
  autoscale_configuration {
    min_capacity = 1
    max_capacity = 3
  }

  waf_configuration {
    enabled          = true
    firewall_mode    = "Prevention"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = var.subnet_agw_id
  }

  # ── Frontend ───────────────────────────────────────────────────────────────

  frontend_ip_configuration {
    name                 = local.frontend_ip_name
    public_ip_address_id = var.public_ip_id
  }

  frontend_port {
    name = local.frontend_port_http
    port = 80
  }

  frontend_port {
    name = local.frontend_port_https
    port = 443
  }

  # SSL certificate pulled from Key Vault via the user-assigned managed identity
  ssl_certificate {
    name                = local.ssl_cert_name
    key_vault_secret_id = var.agw_cert_secret_id
  }

  depends_on = [azurerm_role_assignment.kv_secrets_user]

  # ── Backend pools ──────────────────────────────────────────────────────────

  backend_address_pool {
    name  = local.backend_pool_swa
    fqdns = [var.swa_private_fqdn]
  }

  backend_address_pool {
    name  = local.backend_pool_api
    fqdns = [var.app_service_fqdn]
  }

  # ── Backend HTTP settings ──────────────────────────────────────────────────

  backend_http_settings {
    name                                = local.http_settings_swa
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 30
    pick_host_name_from_backend_address = true
    probe_name                          = local.probe_swa
  }

  backend_http_settings {
    name                                = local.http_settings_api
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 60
    pick_host_name_from_backend_address = true
    probe_name                          = local.probe_api
  }

  # ── Health probes ──────────────────────────────────────────────────────────

  probe {
    name                                      = local.probe_swa
    protocol                                  = "Https"
    path                                      = "/"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
    match {
      status_code = ["200-399"]
    }
  }

  probe {
    name                                      = local.probe_api
    protocol                                  = "Https"
    path                                      = "/health"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
    match {
      status_code = ["200"]
    }
  }

  # ── Listeners ──────────────────────────────────────────────────────────────

  http_listener {
    name                           = local.listener_http
    frontend_ip_configuration_name = local.frontend_ip_name
    frontend_port_name             = local.frontend_port_http
    protocol                       = "Http"
  }

  http_listener {
    name                           = local.listener_https
    frontend_ip_configuration_name = local.frontend_ip_name
    frontend_port_name             = local.frontend_port_https
    protocol                       = "Https"
    ssl_certificate_name           = local.ssl_cert_name
  }

  # ── Redirect HTTP → HTTPS ──────────────────────────────────────────────────

  redirect_configuration {
    name                 = local.redirect_to_https
    redirect_type        = "Permanent"
    target_listener_name = local.listener_https
    include_path         = true
    include_query_string = true
  }

  request_routing_rule {
    name                        = "rule-http-redirect"
    rule_type                   = "Basic"
    http_listener_name          = local.listener_http
    redirect_configuration_name = local.redirect_to_https
    priority                    = 100
  }

  # ── Path-based routing on HTTPS ────────────────────────────────────────────

  url_path_map {
    name                               = local.url_path_map
    default_backend_address_pool_name  = local.backend_pool_swa
    default_backend_http_settings_name = local.http_settings_swa

    path_rule {
      name                       = "api-rule"
      paths                      = ["/api/*"]
      backend_address_pool_name  = local.backend_pool_api
      backend_http_settings_name = local.http_settings_api
    }
  }

  request_routing_rule {
    name               = "rule-https-routing"
    rule_type          = "PathBasedRouting"
    http_listener_name = local.listener_https
    url_path_map_name  = local.url_path_map
    priority           = 110
  }
}

# Diagnostic settings
resource "azurerm_monitor_diagnostic_setting" "agw" {
  name                       = "diag-agw"
  target_resource_id         = azurerm_application_gateway.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
