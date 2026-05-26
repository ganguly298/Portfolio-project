# ============================================================
# deploy.ps1 — One-click deployment for Student Portfolio Platform
# ============================================================

param(
    [string]$ResourceGroup = "rg-portfolio-dev",
    [string]$Location = "centralindia"
)

Write-Host "=== Student Portfolio Platform — Deploy ===" -ForegroundColor Cyan
Write-Host ""

# Prompt for app secret
$appSecret = Read-Host -Prompt "Enter an app secret (any string, stored in Key Vault)" -AsSecureString
$plainSecret = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($appSecret)
)

# Create resource group
Write-Host "`n[1/4] Creating Resource Group: $ResourceGroup..." -ForegroundColor Yellow
az group create --name $ResourceGroup --location $Location --output none

# Deploy Bicep
Write-Host "[2/4] Deploying Bicep template (~2-3 minutes)..." -ForegroundColor Yellow
$result = az deployment group create `
    --resource-group $ResourceGroup `
    --template-file "$PSScriptRoot\main.bicep" `
    --parameters projectName=portfolio appSecret=$plainSecret `
    --query "properties.outputs" `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -eq 0) {
    $funcUrl = $result.functionAppUrl.value
    $funcName = ($funcUrl -replace 'https://', '') -replace '\.azurewebsites\.net', ''

    Write-Host "[3/4] Deployment successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "=== Outputs ===" -ForegroundColor Cyan
    Write-Host "Function App URL: $funcUrl"
    Write-Host "Key Vault URI:    $($result.keyVaultUri.value)"
    Write-Host "Logic App:        $($result.logicAppEndpoint.value)"
    Write-Host "Storage Account:  $($result.storageAccountName.value)"
    Write-Host ""

    # Seed profile data into Table Storage
    Write-Host "[4/4] Seeding profile data into Table Storage..." -ForegroundColor Yellow
    $storageAccount = $result.storageAccountName.value
    $storageKey = (az storage account keys list --resource-group $ResourceGroup --account-name $storageAccount --query "[0].value" -o tsv)

    az storage entity insert `
        --account-name $storageAccount `
        --account-key $storageKey `
        --table-name profiles `
        --entity PartitionKey=portfolio RowKey=saurav `
            name="Saurav Ganguly" `
            title="Cloud Engineering Student" `
            about="Learning cloud infrastructure with Azure for Students. Building serverless APIs and managing IaC with Bicep." `
            skills='["Azure","Bicep","IaC","DevOps","Python","Node.js"]' `
            github="https://github.com/saurav" `
            linkedin="" `
        --output none 2>$null

    Write-Host "Profile data seeded!" -ForegroundColor Green
    Write-Host ""
    Write-Host "=== Test Your API ===" -ForegroundColor Cyan
    Write-Host "  curl $funcUrl/api/profile"
    Write-Host "  curl -X POST $funcUrl/api/contact -H 'Content-Type: application/json' -d '{""name"":""Test"",""email"":""test@test.com"",""message"":""Hello""}'"
    Write-Host ""
    Write-Host "To destroy: .\destroy.ps1" -ForegroundColor Yellow
} else {
    Write-Host "`nDeployment failed. Check errors above." -ForegroundColor Red
}
