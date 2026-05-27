# ============================================================
# deploy.ps1 - One-click deployment for Student Portfolio Platform
# ============================================================

param(
    [string]$ResourceGroup = "rg-portfolio-dev",
    [string]$Location = "centralindia"
)

Write-Host "=== Student Portfolio Platform - Deploy ===" -ForegroundColor Cyan
Write-Host ""

# Prompt for app secret
$appSecret = Read-Host -Prompt "Enter an app secret (any string, stored in Key Vault)" -AsSecureString
$plainSecret = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($appSecret)
)

$az = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'

# Create resource group
Write-Host "`n[1/6] Creating Resource Group: $ResourceGroup..." -ForegroundColor Yellow
& $az group create --name $ResourceGroup --location $Location --output none

# Deploy Bicep
Write-Host "[2/6] Deploying Bicep template (~2-3 minutes)..." -ForegroundColor Yellow
$result = & $az deployment group create `
    --resource-group $ResourceGroup `
    --template-file "$PSScriptRoot\main.bicep" `
    --parameters projectName=portfolio appSecret=$plainSecret `
    --query "properties.outputs" `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -eq 0) {
    $funcUrl = $result.functionAppUrl.value
    $funcName = ($funcUrl -replace 'https://', '') -replace '\.azurewebsites\.net', ''
    $frontendUrl = $result.frontendUrl.value
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

    # ----- Deploy function code (zip from src/api) -----
    Write-Host "[4/6] Packaging and deploying function code..." -ForegroundColor Yellow
    $apiSrc = Join-Path $PSScriptRoot 'src\api'
    $zipPath = Join-Path $env:TEMP "portfolio-api-$(Get-Date -Format 'yyyyMMddHHmmss').zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path (Join-Path $apiSrc '*') -DestinationPath $zipPath -Force
    & $az functionapp deployment source config-zip `
        --resource-group $ResourceGroup `
        --name $funcName `
        --src $zipPath `
        --build-remote true `
        --output none
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Function code deploy failed." -ForegroundColor Red
    } else {
        Write-Host "Function code deployed." -ForegroundColor Green
    }

    # ----- Publish frontend to static website storage -----
    Write-Host "[5/6] Publishing frontend..." -ForegroundColor Yellow
    $frontendSrc = Join-Path $PSScriptRoot 'src\frontend'
    if (Test-Path $frontendSrc) {
        $storageKey = (& $az storage account keys list --resource-group $ResourceGroup --account-name $storageAccount --query "[0].value" -o tsv)
        & $az storage blob service-properties update `
            --account-name $storageAccount `
            --account-key $storageKey `
            --static-website `
            --index-document index.html `
            --404-document index.html `
            --output none
        $frontendTemp = Join-Path $env:TEMP "portfolio-frontend-$(Get-Date -Format 'yyyyMMddHHmmss')"
        if (Test-Path $frontendTemp) { Remove-Item $frontendTemp -Recurse -Force }
        New-Item -ItemType Directory -Path $frontendTemp | Out-Null
        Copy-Item -Path (Join-Path $frontendSrc '*') -Destination $frontendTemp -Recurse -Force
        @"
window.PORTFOLIO_CONFIG = {
  apiBaseUrl: '$funcUrl'
};
"@ | Set-Content -Path (Join-Path $frontendTemp 'config.js') -Encoding ascii

        & $az storage blob upload-batch `
            --account-name $storageAccount `
            --account-key $storageKey `
            --destination '$web' `
            --source $frontendTemp `
            --overwrite true `
            --output none

        & $az functionapp cors add `
            --name $funcName `
            --resource-group $ResourceGroup `
            --allowed-origins ($frontendUrl.TrimEnd('/')) `
            --output none 2>$null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "Frontend published." -ForegroundColor Green
        } else {
            Write-Host "Frontend publish or CORS update failed." -ForegroundColor Red
        }
    } else {
        Write-Host "src\\frontend not found, skipping frontend publish." -ForegroundColor Yellow
    }

    # ----- Seed profile via the dedicated script (handles JSON quoting) -----
    Write-Host "[6/6] Seeding profile data..." -ForegroundColor Yellow
    $seedScript = Join-Path $PSScriptRoot 'scripts\seed-profile.ps1'
    if (Test-Path $seedScript) {
        & $seedScript -ResourceGroup $ResourceGroup -FunctionApp $funcName
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
} else {
    Write-Host "`nDeployment failed. Check errors above." -ForegroundColor Red
}

