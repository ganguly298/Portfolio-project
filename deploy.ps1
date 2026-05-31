# ============================================================
# deploy.ps1 - One-click deployment (Flex Consumption + Managed Identity)
# ============================================================

param(
    [string]$ResourceGroup = "rg-portfolio-dev",
    [string]$Location = "centralindia"
)

Write-Host "=== Student Portfolio Platform - Deploy (Flex Consumption) ===" -ForegroundColor Cyan
Write-Host ""

$appSecret = Read-Host -Prompt "Enter an app secret (any string, stored in Key Vault)" -AsSecureString
$plainSecret = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($appSecret)
)

$az = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'

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
$result = & $az deployment group create `
    --resource-group $ResourceGroup `
    --template-file "$PSScriptRoot\main.bicep" `
    --parameters projectName=portfolio appSecret=$plainSecret `
    --query "properties.outputs" `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nBicep deployment failed. Check errors above." -ForegroundColor Red
    exit 1
}

$funcUrl        = $result.functionAppUrl.value
$funcName       = $result.functionAppName.value
$frontendUrl    = $result.frontendUrl.value
$storageAccount = $result.storageAccountName.value

Write-Host "[3/6] Bicep deployment successful!" -ForegroundColor Green
Write-Host ""
Write-Host "=== Outputs ===" -ForegroundColor Cyan
Write-Host "Function App URL: $funcUrl"
Write-Host "Frontend URL:     $frontendUrl"
Write-Host "Key Vault URI:    $($result.keyVaultUri.value)"
Write-Host "Logic App:        $($result.logicAppEndpoint.value)"
Write-Host "Storage Account:  $storageAccount"
Write-Host ""

# ─── 4. Deploy function code (Flex one-deploy) ───────────────
Write-Host "[4/6] Packaging and deploying function code..." -ForegroundColor Yellow
$apiSrc = Join-Path $PSScriptRoot 'src\api'
$zipPath = Join-Path $env:TEMP "portfolio-api-$(Get-Date -Format 'yyyyMMddHHmmss').zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $apiSrc '*') -DestinationPath $zipPath -Force

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
    @"
window.PORTFOLIO_CONFIG = {
  apiBaseUrl: '$funcUrl'
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
Write-Host "  curl $funcUrl/api/profile"
Write-Host "  curl -X POST $funcUrl/api/contact -H 'Content-Type: application/json' -d '{""name"":""Test"",""email"":""test@test.com"",""message"":""Hello""}'"
Write-Host ""
Write-Host "Smoke test: .\scripts\smoke-test.ps1" -ForegroundColor Cyan
Write-Host "To destroy: .\destroy.ps1" -ForegroundColor Yellow
