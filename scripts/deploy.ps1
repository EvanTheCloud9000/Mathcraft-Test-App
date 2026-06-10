#Requires -Version 5.1
<#
.SYNOPSIS
  Full deploy: terraform apply → build React → deploy SWA → upload API to blob → restart App Service
.DESCRIPTION
  Run from the repo root: .\scripts\deploy.ps1
  Prerequisites: az CLI, terraform, node >=20, npm, swa CLI (npm i -g @azure/static-web-apps-cli)
  The App Service is fully private. Deployment uses Run from Package: the API zip is uploaded
  to Azure Blob Storage and the App Service pulls it via private endpoint using its managed identity.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot  = Split-Path $PSScriptRoot -Parent
$InfraDir  = Join-Path $RepoRoot 'infra'
$ClientDir = Join-Path $RepoRoot 'app\client'
$ApiDir    = Join-Path $RepoRoot 'app\api'
$BuildDir  = Join-Path $ClientDir 'build'
$ZipPath   = Join-Path $env:TEMP 'employee-api.zip'

function Step([string]$msg) {
  Write-Host "`n==> $msg" -ForegroundColor Cyan
}

# ── 1. Terraform ──────────────────────────────────────────────────────────────

Step "Running terraform apply"
Push-Location $InfraDir
terraform apply -auto-approve
$TfOutputs      = terraform output -json | ConvertFrom-Json
Pop-Location

$AppServiceName  = $TfOutputs.app_service_name.value
$KvName          = ($TfOutputs.key_vault_uri.value -replace 'https://|\.vault\.azure\.net.*', '')
$RgName          = $TfOutputs.resource_group_name.value
$StorageName     = $TfOutputs.storage_account_name.value

# ── 2. Build React ────────────────────────────────────────────────────────────

Step "Installing and building React app"
Push-Location $ClientDir
npm ci
npm run build
Pop-Location

# ── 3. Deploy Static Web App ──────────────────────────────────────────────────

Step "Fetching SWA deployment token from Key Vault"
$SwaToken = (az keyvault secret show --vault-name $KvName --name 'swa-deployment-token' --query 'value' -o tsv)

Step "Deploying React build to Static Web App"
swa deploy $BuildDir --deployment-token $SwaToken --no-use-keychain

# ── 4. Package and upload Node.js API ─────────────────────────────────────────

Step "Installing API dependencies (production only)"
Push-Location $ApiDir
npm ci --omit=dev
Pop-Location

Step "Creating deployment zip"
Compress-Archive -Path "$ApiDir\*" -DestinationPath $ZipPath -Force

Step "Uploading API package to blob storage: $StorageName/packages/employee-api.zip"
az storage blob upload `
  --account-name $StorageName `
  --container-name packages `
  --name employee-api.zip `
  --file $ZipPath `
  --auth-mode login `
  --overwrite

Remove-Item $ZipPath -Force

# ── 5. Restart App Service to pick up new package ─────────────────────────────

Step "Restarting App Service: $AppServiceName"
az webapp restart --resource-group $RgName --name $AppServiceName

Step "Deploy complete"
Write-Host "App Gateway IP : $($TfOutputs.app_gateway_public_ip.value)" -ForegroundColor Green
Write-Host "Access the app : https://$($TfOutputs.app_gateway_public_ip.value)" -ForegroundColor Green
