# Employee Directory — Azure Full-Stack Demo

A full-stack employee directory application built as an enterprise-grade Azure deployment. React SPA frontend, Node.js/Express API, Cosmos DB data layer — all traffic private, all secrets managed, all infrastructure as Terraform code.

---

## Architecture

```
Internet
    │
    ▼ HTTPS (443) / HTTP→HTTPS redirect (80)
┌─────────────────────────────────────────────────────────────────┐
│  Application Gateway WAF v2  (appgw-snet  10.0.0.0/24)         │
│  OWASP 3.2 Prevention mode · autoscale 1–3 · zone-redundant    │
└──────────────┬───────────────────────────┬──────────────────────┘
               │ /*  (HTTPS 443)            │ /api/*  (HTTPS 443)
               ▼                            ▼
┌──────────────────────────────────────────────────────────────────┐
│  app-snet  10.0.1.0/24                                           │
│                                                                  │
│  ┌─────────────────────────┐   ┌──────────────────────────────┐ │
│  │ Static Web App          │   │ App Service                  │ │
│  │ private endpoint        │   │ private endpoint             │ │
│  │ (React SPA)             │   │ (Node.js / Express API)      │ │
│  └─────────────────────────┘   └──────────────┬───────────────┘ │
│                                               │ VNet integration │
└───────────────────────────────────────────────┼──────────────────┘
                                                │ (outbound via VNet)
               ┌────────────────────────────────┤
               │                                │
               ▼ HTTPS 443                      ▼ HTTPS 443
┌──────────────────────────┐   ┌────────────────────────────────────┐
│ db-snet  10.0.2.0/24     │   │ platform-snet  10.0.3.0/24         │
│                          │   │                                    │
│  Cosmos DB SQL           │   │  Key Vault PE                      │
│  private endpoint        │   │  AMPLS PE (Log Analytics +         │
│                          │   │           App Insights)            │
│                          │   │  All private DNS zones             │
└──────────────────────────┘   └────────────────────────────────────┘

Internet-bound egress from app-snet:
  app-snet → UDR (0.0.0.0/0) → Azure Firewall (AzureFirewallSubnet 10.0.4.0/24)
  Firewall allows: Azure AD (login.microsoftonline.com, graph.microsoft.com)
                   npm registry (registry.npmjs.org)
  Everything else: dropped at the firewall
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | React 18 (TypeScript), Azure Static Web Apps Standard |
| Backend | Node.js 20 LTS, Express, Azure App Service Linux P1v3 |
| Database | Azure Cosmos DB SQL/Core API |
| Infrastructure | Terraform ~> 3.100, azurerm provider |
| Ingress | Azure Application Gateway WAF v2 |
| Secrets | Azure Key Vault (RBAC mode) |
| Observability | Azure Monitor, Log Analytics, Application Insights, AMPLS |
| Egress control | Azure Firewall Standard |
| DDoS | Azure DDoS Protection Standard |

---

## Infrastructure Modules

```
infra/
├── main.tf                  # Root orchestration + cross-module RBAC wiring
├── variables.tf
├── outputs.tf
├── providers.tf
└── modules/
    ├── networking/          # VNet, 5 subnets, NSGs, private DNS zones, DDoS plan
    ├── monitoring/          # Log Analytics, App Insights, AMPLS private endpoint
    ├── firewall/            # Azure Firewall, firewall policy, egress rules, UDR
    ├── key_vault/           # Key Vault (RBAC), self-signed SSL cert, private endpoint
    ├── cosmos/              # Cosmos DB account, employeedb database, employees container
    ├── app_service/         # App Service Plan, Linux web app, private endpoint
    ├── static_web_app/      # SWA (Standard SKU), private endpoint
    └── app_gateway/         # WAF v2, path-based routing, HTTP→HTTPS redirect
```

---

## Network Topology

| Subnet | CIDR | Contents |
|---|---|---|
| `appgw-snet` | 10.0.0.0/24 | Application Gateway WAF v2 |
| `app-snet` | 10.0.1.0/24 | SWA private endpoint + App Service VNet integration + App Service private endpoint |
| `db-snet` | 10.0.2.0/24 | Cosmos DB SQL private endpoint |
| `platform-snet` | 10.0.3.0/24 | Key Vault PE + AMPLS PE + all private DNS zones |
| `AzureFirewallSubnet` | 10.0.4.0/24 | Azure Firewall Standard (reserved name, no NSG) |

Every subnet has its own NSG with explicit CIDR-based rules. No `VirtualNetwork` service tag is used — each rule names the exact source or destination CIDR to prevent lateral movement between subnets:

| NSG | Inbound allows |
|---|---|
| appgw-snet | Internet → 443, Internet → 80, GatewayManager → 65200-65535, AzureLoadBalancer → * |
| app-snet | appgw-snet → 443 only |
| db-snet | app-snet → 443 only |
| platform-snet | app-snet → 443, appgw-snet → 443 (App Gateway pulls SSL cert from Key Vault) |

All four NSGs have an explicit deny-all-inbound at priority 4096.

---

## Security Design

### No public endpoints
Every backend resource — App Service, SWA, Cosmos DB, Key Vault — has `public_network_access_enabled = false`. All inbound traffic arrives through private endpoints within the VNet. The only public-facing surface is the Application Gateway.

### Managed Identity — no credentials in code

User-assigned managed identities are used for all resources that need to authenticate to other Azure services. User-assigned (rather than system-assigned) was chosen deliberately: the identity has an independent lifecycle from the resource it is attached to, so if App Service or App Gateway is destroyed and recreated, the principal ID stays the same and all RBAC assignments remain valid without any manual remediation.

Two identities are provisioned by Terraform:

| Identity | Attached to | RBAC assignments |
|---|---|---|
| `id-app-*` | App Service | Cosmos DB Built-in Data Contributor · Key Vault Secrets User |
| `id-agw-*` | App Gateway | Key Vault Secrets User |

Wiring a user-assigned identity correctly requires three things, all of which are configured:

**1. Identity attached to the resource**
The identity ID is listed in the `identity` block of the resource. This makes the identity available on the resource but does not on its own tell anything which identity to use — that is the job of steps 2 and 3.

**2. `key_vault_reference_identity_id` on App Service**
App Service supports Key Vault references in app settings (`@Microsoft.KeyVault(SecretUri=...)`). When the runtime starts up it resolves these references by calling Key Vault on behalf of the app. With a user-assigned identity, `key_vault_reference_identity_id` must be set to tell the runtime which identity to present to Key Vault — otherwise the resolution fails even if the RBAC assignment exists.

**3. `AZURE_CLIENT_ID` app setting**
The Node.js API uses `DefaultAzureCredential` from `@azure/identity` to obtain tokens at runtime — for example, when querying Cosmos DB. `DefaultAzureCredential` probes several credential sources in order; when it reaches the managed identity source it calls the IMDS token endpoint. If more than one identity is attached, or simply as an explicit best practice, `AZURE_CLIENT_ID` must be set to the client ID of the intended identity. Without it the token request is ambiguous and will fail.

These three settings together form the complete chain: the identity exists on the resource, the infrastructure-side Key Vault resolution knows which identity to use, and the application-side SDK knows which identity to request tokens for.

### Key Vault secret references
The Cosmos DB endpoint is stored in Key Vault and consumed by App Service via a Key Vault reference app setting (`@Microsoft.KeyVault(SecretUri=...)`). The App Service runtime resolves the reference at startup using `id-app-*` (via `key_vault_reference_identity_id`) — the plaintext value is injected into the process environment and is never written to Terraform state or visible in the Azure portal app settings blade.

### Egress control
App Service has `vnet_route_all_enabled = true`, which forces all outbound traffic through the VNet. A UDR on app-snet sends `0.0.0.0/0` to the Azure Firewall's private IP. The firewall's application rule collection allows only:
- Azure AD / MSAL endpoints (managed identity token acquisition)
- npm registry (build-time dependency resolution)

All other internet destinations are dropped by the firewall.

### WAF
Application Gateway runs in WAF v2 Prevention mode with OWASP Core Rule Set 3.2. HTTP traffic on port 80 is permanently redirected to HTTPS before any backend connection is made.

### DDoS Protection
Azure DDoS Protection Standard is enabled on the VNet, providing adaptive tuning and attack telemetry against volumetric and protocol attacks at the network layer.

### NSG design
Each subnet's NSG uses hardcoded CIDRs rather than service tags like `VirtualNetwork`. This means a compromised resource in one subnet cannot use its subnet membership to reach resources in a different subnet — traffic is permitted only to the specific destination CIDRs it legitimately needs.

### SSL
The App Gateway SSL certificate is a self-signed cert generated in Key Vault (`CN=employee-app.internal`). In production this would be replaced with a CA-issued certificate. The cert is never stored outside Key Vault — App Gateway pulls it via the managed identity reference at startup.

---

## Private DNS Zones

| Zone | Resolves |
|---|---|
| `privatelink.documents.azure.com` | Cosmos DB private endpoint |
| `privatelink.vaultcore.azure.net` | Key Vault private endpoint |
| `privatelink.azurewebsites.net` | App Service private endpoint |
| `privatelink.azurestaticapps.net` | Static Web App private endpoint |
| `privatelink.monitor.azure.com` | AMPLS |
| `privatelink.ods.opinsights.azure.com` | AMPLS |
| `privatelink.oms.opinsights.azure.com` | AMPLS |
| `privatelink.blob.core.windows.net` | AMPLS |
| `privatelink.agentsvc.azure-automation.net` | AMPLS |

All zones are linked to the VNet. `WEBSITE_DNS_SERVER = 168.63.129.16` is set on App Service so the runtime uses Azure DNS and resolves private zones correctly from within the VNet integration subnet.

---

## Deployment

### Prerequisites

- Azure subscription (Owner or Contributor + User Access Administrator)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Node.js](https://nodejs.org/) >= 20
- [SWA CLI](https://azure.github.io/static-web-apps-cli/): `npm install -g @azure/static-web-apps-cli`
- A self-hosted GitHub Actions runner (or equivalent pipeline agent) deployed inside the VNet — Key Vault has no public endpoint, so Terraform must run from within the VNet.

### Steps

**1. Authenticate**
```sh
az login
az account set --subscription <subscription-id>
```

**2. Configure variables**
```sh
cp infra/terraform.tfvars.example infra/terraform.tfvars
# Edit terraform.tfvars — set project_name, environment, location
```

**3. Full deploy (Terraform + React build + SWA deploy + API zip-deploy)**
```powershell
.\scripts\deploy.ps1
```

The script:
1. Runs `terraform init` and `terraform apply`
2. Builds the React app (`npm ci && npm run build`)
3. Fetches the SWA deployment token from Key Vault and deploys the static build
4. Zip-deploys the Node.js API to App Service
5. Prints the Application Gateway public IP on completion

The API seeds 8 sample employees into Cosmos DB on first startup.

### Manual steps (if not using the script)

```sh
# Infrastructure
cd infra
terraform init
terraform apply

# Frontend
cd app/client
npm ci && npm run build

# Deploy SWA (token from Key Vault)
swa deploy ./build --deployment-token <token>

# Deploy API
cd app/api
npm ci --omit=dev
# Zip and deploy via az webapp deploy
```

---

## Observability

- **Application Insights** (workspace-based) — request traces, dependency tracking, exceptions
- **Log Analytics Workspace** — centralised log sink for all resources
- **Diagnostic settings** on every resource: App Gateway access + WAF logs, App Service HTTP + console logs, Cosmos DB data plane requests, Key Vault audit events, Firewall application + network rule logs
- **AMPLS** (Azure Monitor Private Link Scope) — all monitoring traffic stays within the VNet; no telemetry exits to the public internet

---

## Project Structure

```
.
├── app/
│   ├── api/                 # Node.js Express API
│   │   └── src/
│   │       ├── index.js     # Entry point, /health endpoint, seed on startup
│   │       ├── cosmos.js    # CosmosClient with DefaultAzureCredential
│   │       └── routes/
│   │           └── employees.js
│   └── client/              # React TypeScript SPA
│       └── src/
│           ├── App.tsx
│           ├── components/
│           │   └── EmployeeList.tsx
│           └── types/
│               └── Employee.ts
├── infra/                   # Terraform root + modules
└── scripts/
    └── deploy.ps1           # End-to-end deploy script
```

---

## Production Considerations

**Terraform remote state**
State is local for this demo (`*.tfstate` is gitignored). In production: Azure Storage backend with state locking, a separate storage account and key per environment (dev/staging/prod), workspace isolation, and the pipeline identity granted Storage Blob Data Contributor on the state container only. The commented-out backend block in `providers.tf` shows where this would be wired.

**app-snet dual use**
`app-snet` hosts both the App Service VNet integration (outbound, `Microsoft.Web/serverFarms` delegation) and the SWA and App Service private endpoints (inbound). Azure supports this combination, and NSG + UDR behaviour is correct. In a production environment with stricter blast-radius requirements these would typically be split into separate subnets — one delegated integration subnet for outbound, one clean PE subnet for inbound — making NSG rules and routing easier to reason about independently.

**CORS**
`allowed_origins = ["*"]` on App Service is intentional for the demo. In production, lock this to the frontend custom domain (e.g. `https://employees.contoso.com`).

**SSL certificate**
The App Gateway SSL certificate is self-signed (`CN=employee-app.internal`). Replace `azurerm_key_vault_certificate.agw_ssl` with a CA-issued certificate and update the App Gateway SSL certificate block. Pair with a custom domain and DNS A record pointing to the App Gateway public IP.

**DDoS Protection Standard**
Carries a significant base cost (~$2,944/month). Remove `azurerm_network_ddos_protection_plan` and the `ddos_protection_plan` block from the VNet resource if cost is a constraint in non-production environments.
