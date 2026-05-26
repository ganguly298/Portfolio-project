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

# Create resource group
Write-Host "`n[1/5] Creating Resource Group: $ResourceGroup..." -ForegroundColor Yellow
az group create --name $ResourceGroup --location $Location --output none

# Deploy Bicep
Write-Host "[2/5] Deploying Bicep template (~2-3 minutes)..." -ForegroundColor Yellow
$result = az deployment group create `
    --resource-group $ResourceGroup `
    --template-file "$PSScriptRoot\main.bicep" `
    --parameters projectName=portfolio appSecret=$plainSecret `
    --query "properties.outputs" `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -eq 0) {
    $funcUrl = $result.functionAppUrl.value
    $funcName = ($funcUrl -replace 'https://', '') -replace '\.azurewebsites\.net', ''

    Write-Host "[3/5] Bicep deployment successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "=== Outputs ===" -ForegroundColor Cyan
    Write-Host "Function App URL: $funcUrl"
    Write-Host "Key Vault URI:    $($result.keyVaultUri.value)"
    Write-Host "Logic App:        $($result.logicAppEndpoint.value)"
    Write-Host "Storage Account:  $($result.storageAccountName.value)"
    Write-Host ""

    # ----- Deploy function code (zip from src/api) -----
    Write-Host "[4/5] Packaging and deploying function code..." -ForegroundColor Yellow
    $apiSrc = Join-Path $PSScriptRoot 'src\api'
    $zipPath = Join-Path $env:TEMP "portfolio-api-$(Get-Date -Format 'yyyyMMddHHmmss').zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path (Join-Path $apiSrc '*') -DestinationPath $zipPath -Force
    az functionapp deployment source config-zip `
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

    # ----- Seed profile via the dedicated script (handles JSON quoting) -----
    Write-Host "[5/5] Seeding profile data..." -ForegroundColor Yellow
    $seedScript = Join-Path $PSScriptRoot 'scripts\seed-profile.ps1'
    if (Test-Path $seedScript) {
        & $seedScript -ResourceGroup $ResourceGroup -FunctionApp $funcName
    } else {
        Write-Host "seed-profile.ps1 not found, skipping seed." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "=== Test Your API ===" -ForegroundColor Cyan
    Write-Host "  curl $funcUrl/api/profile"
    Write-Host "  curl -X POST $funcUrl/api/contact -H 'Content-Type: application/json' -d '{""name"":""Test"",""email"":""test@test.com"",""message"":""Hello""}'"
    Write-Host ""
    Write-Host "Smoke test: .\scripts\smoke-test.ps1" -ForegroundColor Cyan
    Write-Host "To destroy: .\destroy.ps1" -ForegroundColor Yellow
} else {
    Write-Host "`nDeployment failed. Check errors above." -ForegroundColor Red
}
