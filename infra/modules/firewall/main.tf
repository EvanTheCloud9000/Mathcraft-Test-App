resource "azurerm_public_ip" "firewall" {
  name                = "pip-fw-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_firewall_policy" "main" {
  name                = "fwpol-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "egress" {
  name               = "fwrcg-app-egress"
  firewall_policy_id = azurerm_firewall_policy.main.id
  priority           = 200

  # Allow only what app-snet legitimately needs to reach on the internet.
  # Private endpoint traffic (Cosmos DB, Key Vault, AMPLS) never reaches the
  # firewall — those destinations resolve to RFC1918 IPs via private DNS and
  # are routed locally within the VNet.
  application_rule_collection {
    name     = "allow-app-egress"
    priority = 200
    action   = "Allow"

    rule {
      name              = "allow-azure-ad"
      source_addresses  = [var.app_subnet_cidr]
      destination_fqdns = [
        "login.microsoftonline.com",
        "*.identity.azure.net",
        "graph.microsoft.com",
      ]
      protocols {
        type = "Https"
        port = 443
      }
    }

    rule {
      name              = "allow-npm"
      source_addresses  = [var.app_subnet_cidr]
      destination_fqdns = [
        "registry.npmjs.org",
        "*.npmjs.org",
      ]
      protocols {
        type = "Https"
        port = 443
      }
    }
  }
}

resource "azurerm_firewall" "main" {
  name                = "fw-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.main.id
  zones               = ["1", "2", "3"]

  ip_configuration {
    name                 = "fw-ipconfig"
    subnet_id            = var.subnet_firewall_id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  tags = var.tags
}

# Route all egress from app-snet through the firewall.
# More-specific VNet routes still win, so PE traffic (10.0.x.x) bypasses this
# and reaches private endpoints directly.
resource "azurerm_route_table" "app_egress" {
  name                          = "rt-app-egress-${var.name_prefix}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  bgp_route_propagation_enabled = false

  route {
    name                   = "egress-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address
  }

  tags = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                       = "diag-fw"
  target_resource_id         = azurerm_firewall.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AzureFirewallApplicationRule"
  }

  enabled_log {
    category = "AzureFirewallNetworkRule"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
