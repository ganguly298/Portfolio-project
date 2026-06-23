# ============================================================
# deploy.ps1 - One-click deployment (Flex Consumption + Managed Identity)
# ============================================================

param(
    [string]$ResourceGroup = "rg-portfolio-dev",
    [string]$Location = "centralindia",
    [string]$AppSecret = $env:APP_SECRET,
    [switch]$EnableEntraAuth,
    [string]$EntraTenantId = $env:ENTRA_TENANT_ID,
    [string]$EntraFrontendClientId = $env:ENTRA_FRONTEND_CLIENT_ID,
    [string]$EntraApiClientId = $env:ENTRA_API_CLIENT_ID,
    [string]$EntraApiScope = $env:ENTRA_API_SCOPE
)

Write-Host "=== Student Portfolio Platform - Deploy (Flex Consumption) ===" -ForegroundColor Cyan
Write-Host "EnableEntraAuth switch present: $([bool]$EnableEntraAuth.IsPresent)" -ForegroundColor DarkGray
Write-Host ""

if (-not $AppSecret) {
    $secure = Read-Host -Prompt "Enter an app secret (any string, stored in Key Vault)" -AsSecureString
    $AppSecret = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    )
}
$plainSecret = $AppSecret

if ($EnableEntraAuth) {
    $missing = @()
    if (-not $EntraTenantId) { $missing += 'EntraTenantId' }
    if (-not $EntraFrontendClientId) { $missing += 'EntraFrontendClientId' }
    if (-not $EntraApiClientId) { $missing += 'EntraApiClientId' }
    if ($missing.Count -gt 0) {
        Write-Host "Missing required Entra auth parameter(s): $($missing -join ', ')" -ForegroundColor Red
        Write-Host "Create the Entra app registrations first, then rerun deploy.ps1 with those values." -ForegroundColor Yellow
        exit 1
    }
    if (-not $EntraApiScope) {
        $EntraApiScope = "api://$EntraApiClientId/access_as_user"
    }
}

# Resolve `az` per-platform: Windows CLI installer puts it at a fixed path,
# Linux/Mac (and pipeline agents) just have `az` on PATH.
if ($IsWindows -and (Test-Path 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd')) {
    $az = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'
} else {
    $az = 'az'
}

# ─── 1. Resource group ───────────────────────────────────────
Write-Host "`n[1/6] Ensuring Resource Group: $ResourceGroup..." -ForegroundColor Yellow
& $az group create --name $ResourceGroup --location $Location --output none

# ─── 1a. Purge any soft-deleted Key Vaults that would block Bicep ─
# KV soft-delete is mandatory (retention configured to 7 days in
# modules/keyVault.bicep); a same-named vault in deleted state causes
# ConflictError on redeploy. Purge anything matching our project prefix
# in this location before deploying.
Write-Host "[1a/6] Checking for soft-deleted Key Vaults to purge..." -ForegroundColor Yellow
$deleted = & $az keyvault list-deleted -o json | ConvertFrom-Json |
    Where-Object { $_.name -like 'portfolio*' -and $_.properties.location -eq $Location }
foreach ($d in $deleted) {
    Write-Host "  Purging $($d.name)..." -ForegroundColor DarkYellow
    & $az keyvault purge --name $d.name --location $Location --no-wait
}
if ($deleted.Count -gt 0) {
    Write-Host "  Waiting for purges to complete..." -ForegroundColor DarkYellow
    do {
        Start-Sleep 10
        $left = & $az keyvault list-deleted -o json | ConvertFrom-Json |
            Where-Object { $_.name -like 'portfolio*' -and $_.properties.location -eq $Location }
    } while ($left.Count -gt 0)
    Write-Host "  All soft-deleted vaults purged." -ForegroundColor Green
}

# ─── 2. Tear down any pre-existing Y1 function app/plan ──────
# Plan SKU can't be changed in place (Y1 -> FC1), so if the names already
# exist on the old Consumption SKU, delete them so Bicep can recreate as FC1.
$existingFuncs = & $az functionapp list --resource-group $ResourceGroup --query "[?starts_with(name, 'portfolio-func-')].{name:name, sku:appServicePlanId}" -o json | ConvertFrom-Json
foreach ($f in $existingFuncs) {
    $planName = ($f.sku -split '/')[-1]
    $planSku = & $az appservice plan show --name $planName --resource-group $ResourceGroup --query "sku.name" -o tsv 2>$null
    if ($planSku -and $planSku -ne 'FC1') {
        Write-Host "[1.5/6] Deleting existing $($f.name) (plan SKU=$planSku) so Flex plan can be created..." -ForegroundColor Yellow
        & $az functionapp delete --name $f.name --resource-group $ResourceGroup --output none
        & $az appservice plan delete --name $planName --resource-group $ResourceGroup --yes --output none 2>$null
    }
}

# ─── 3. Bicep ────────────────────────────────────────────────
Write-Host "[2/6] Deploying Bicep template (~2-3 minutes)..." -ForegroundColor Yellow

# Write parameters to a temp JSON file so cmd.exe never sees the secret
# value on the command line (avoids issues with special chars like &, |, <, >).
$paramsFile = Join-Path $env:TEMP "portfolio-params-$(Get-Random).json"
@{
    '$schema'      = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
    contentVersion = '1.0.0.0'
    parameters     = @{
        projectName       = @{ value = 'portfolio' }
        appSecret         = @{ value = $plainSecret }
        enableEntraAuth   = @{ value = [bool]$EnableEntraAuth }
        entraTenantId     = @{ value = $EntraTenantId }
        entraApiClientId  = @{ value = $EntraApiClientId }
    }
} | ConvertTo-Json -Depth 5 | Set-Content -Path $paramsFile -Encoding utf8

$result = & $az deployment group create `
    --resource-group $ResourceGroup `
    --template-file "$PSScriptRoot\main.bicep" `
    --parameters "@$paramsFile" `
    --query "properties.outputs" `
    --output json | ConvertFrom-Json

Remove-Item $paramsFile -Force -ErrorAction SilentlyContinue

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nBicep deployment failed. Check errors above." -ForegroundColor Red
    exit 1
}

$funcUrl        = $result.functionAppUrl.value
$funcName       = $result.functionAppName.value
$frontendUrl    = $result.frontendUrl.value
$storageAccount = $result.storageAccountName.value
$entraAuthEnabled = [bool]$result.entraAuthEnabled.value

Write-Host "[3/6] Bicep deployment successful!" -ForegroundColor Green
Write-Host ""
Write-Host "=== Outputs ===" -ForegroundColor Cyan
Write-Host "Function App URL: $funcUrl"
Write-Host "Frontend URL:     $frontendUrl"
Write-Host "Key Vault URI:    $($result.keyVaultUri.value)"
Write-Host "Logic App:        $($result.logicAppEndpoint.value)"
Write-Host "Storage Account:  $storageAccount"
Write-Host "Entra Auth:       $entraAuthEnabled"
Write-Host ""

# ─── 4. Deploy function code (Flex one-deploy) ───────────────
Write-Host "[4/6] Packaging and deploying function code..." -ForegroundColor Yellow
$apiSrc = Join-Path $PSScriptRoot 'src\api'
$zipPath = Join-Path $env:TEMP "portfolio-api-$(Get-Date -Format 'yyyyMMddHHmmss').zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $apiSrc '*') -DestinationPath $zipPath -Force

# Diagnostic: list what actually went into the zip so we can confirm every
# function folder is present before the host tries to register them.
Write-Host "  Zip contents:" -ForegroundColor DarkGray
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
$archive.Entries | Select-Object -ExpandProperty FullName | Sort-Object |
    ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
$archive.Dispose()

# Wait for the Flex SCM/Kudu site to be reachable (it lags ~30-60s behind ARM).
$scmUrl = "https://$funcName.scm.azurewebsites.net"
Write-Host "  Waiting for SCM site at $scmUrl ..." -ForegroundColor DarkYellow
$scmReady = $false
for ($i = 1; $i -le 30; $i++) {
    try {
        $code = (Invoke-WebRequest -Uri $scmUrl -Method Head -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop).StatusCode
        if ($code -lt 500) { $scmReady = $true; break }
    } catch { }
    Start-Sleep 10
}
if (-not $scmReady) { Write-Host "  SCM site never came up. Continuing anyway." -ForegroundColor Red }

# Flex Consumption uses "one deploy": az functionapp deployment source config-zip
# with --build-remote true so the host installs node_modules from package.json.
$deployOk = $false
for ($attempt = 1; $attempt -le 3; $attempt++) {
    & $az functionapp deployment source config-zip `
        --resource-group $ResourceGroup `
        --name $funcName `
        --src $zipPath `
        --build-remote true `
        --output none
    if ($LASTEXITCODE -eq 0) { $deployOk = $true; break }
    Write-Host "  Function deploy attempt $attempt failed; retrying in 30s..." -ForegroundColor DarkYellow
    Start-Sleep 30
}
if (-not $deployOk) {
    Write-Host "Function code deploy failed after 3 attempts." -ForegroundColor Red
    exit 1
}
Write-Host "Function code deployed." -ForegroundColor Green

# Diagnostic: wait briefly for the host to scan the package, then list
# the functions it actually registered. If something is missing, this is
# where we'll see it (instead of guessing from 404s in smoke tests).
Write-Host "  Waiting 60s for host to scan deployed package..." -ForegroundColor DarkGray
Start-Sleep 60
Write-Host "  Registered functions on $funcName :" -ForegroundColor DarkGray
$registered = & $az functionapp function list -g $ResourceGroup -n $funcName --query "[].name" -o tsv 2>$null
if ($registered) {
    ($registered -split "`n" | Where-Object { $_ }) | ForEach-Object {
        Write-Host "    - $_" -ForegroundColor DarkGray
    }
} else {
    Write-Host "    (none reported yet by ARM; host may still be initialising)" -ForegroundColor DarkYellow
}

# ─── 5. Publish frontend ─────────────────────────────────────
Write-Host "[5/6] Publishing frontend..." -ForegroundColor Yellow
$frontendSrc = Join-Path $PSScriptRoot 'src\frontend'
if (Test-Path $frontendSrc) {
    $storageKey = (& $az storage account keys list --resource-group $ResourceGroup --account-name $storageAccount --query "[0].value" -o tsv)

    # The blob data-plane endpoint for a brand-new account can take 30-60s
    # to accept service-properties writes. Retry the enable until it sticks,
    # then poll service-properties to confirm staticWebsite.enabled == true.
    Write-Host "  Enabling static website hosting (with retries)..." -ForegroundColor DarkYellow
    $swEnabled = $false
    for ($attempt = 1; $attempt -le 10; $attempt++) {
        & $az storage blob service-properties update `
            --account-name $storageAccount `
            --account-key $storageKey `
            --static-website `
            --index-document index.html `
            --404-document index.html `
            --output none 2>$null
        Start-Sleep 5
        $enabled = & $az storage blob service-properties show --account-name $storageAccount --account-key $storageKey --query "staticWebsite.enabled" -o tsv 2>$null
        if ($enabled -eq 'true') { $swEnabled = $true; break }
        Write-Host "    attempt $attempt - not enabled yet, retrying..." -ForegroundColor DarkGray
        Start-Sleep 10
    }
    if (-not $swEnabled) { Write-Host "Failed to enable static website hosting." -ForegroundColor Red; exit 1 }

    # Wait for the $web container to materialize after static-website is enabled.
    Write-Host "  Waiting for `$web container..." -ForegroundColor DarkYellow
    $containerReady = $false
    for ($i = 1; $i -le 30; $i++) {
        $exists = & $az storage container exists --account-name $storageAccount --account-key $storageKey --name '$web' --query exists -o tsv 2>$null
        if ($exists -eq 'true') { $containerReady = $true; break }
        Start-Sleep 5
    }
    if (-not $containerReady) { Write-Host "`$web container never appeared." -ForegroundColor Red; exit 1 }

    $frontendTemp = Join-Path $env:TEMP "portfolio-frontend-$(Get-Date -Format 'yyyyMMddHHmmss')"
    if (Test-Path $frontendTemp) { Remove-Item $frontendTemp -Recurse -Force }
    New-Item -ItemType Directory -Path $frontendTemp | Out-Null
    Copy-Item -Path (Join-Path $frontendSrc '*') -Destination $frontendTemp -Recurse -Force
    $authEnabledText = if ($EnableEntraAuth) { 'true' } else { 'false' }
    @"
window.PORTFOLIO_CONFIG = {
    apiBaseUrl: '$funcUrl',
    auth: {
        enabled: $authEnabledText,
        tenantId: '$EntraTenantId',
        clientId: '$EntraFrontendClientId',
        apiScope: '$EntraApiScope'
    }
};
"@ | Set-Content -Path (Join-Path $frontendTemp 'config.js') -Encoding ascii

    $uploadOk = $false
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        & $az storage blob upload-batch `
            --account-name $storageAccount `
            --account-key $storageKey `
            --destination '$web' `
            --source $frontendTemp `
            --overwrite true `
            --output none
        if ($LASTEXITCODE -eq 0) { $uploadOk = $true; break }
        Write-Host "  Frontend upload attempt $attempt failed; retrying in 10s..." -ForegroundColor DarkYellow
        Start-Sleep 10
    }
    if (-not $uploadOk) { Write-Host "Frontend upload failed after 3 attempts." -ForegroundColor Red; exit 1 }

    & $az functionapp cors add `
        --name $funcName `
        --resource-group $ResourceGroup `
        --allowed-origins ($frontendUrl.TrimEnd('/')) `
        --output none 2>$null

    Write-Host "Frontend published." -ForegroundColor Green
} else {
    Write-Host "src\\frontend not found, skipping frontend publish." -ForegroundColor Yellow
}

# ─── 6. Seed profile ─────────────────────────────────────────
Write-Host "[6/6] Seeding profile data..." -ForegroundColor Yellow
$seedScript = Join-Path $PSScriptRoot 'scripts\seed-profile.ps1'
if (Test-Path $seedScript) {
    & $seedScript -ResourceGroup $ResourceGroup -StorageAccount $storageAccount -FunctionApp $funcName
} else {
    Write-Host "seed-profile.ps1 not found, skipping seed." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Test Your App ===" -ForegroundColor Cyan
Write-Host "  Open $frontendUrl"
if ($EnableEntraAuth) {
    Write-Host "  API auth is enabled. Use the frontend sign-in flow, or call the API with a Bearer token for scope: $EntraApiScope"
} else {
    Write-Host "  curl $funcUrl/api/profile"
    Write-Host "  curl -X POST $funcUrl/api/contact -H 'Content-Type: application/json' -d '{""name"":""Test"",""email"":""test@test.com"",""message"":""Hello""}'"
}
Write-Host ""
Write-Host "Smoke test: .\scripts\smoke-test.ps1" -ForegroundColor Cyan
Write-Host "To destroy: .\destroy.ps1" -ForegroundColor Yellow
