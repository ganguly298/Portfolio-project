# ============================================================
# deploy.ps1 — One-click deployment for Student Portfolio Platform
# ============================================================

param(
    [string]$ResourceGroup = "rg-portfolio-dev",
    [string]$Location = "centralindia",
    [string]$MyPublicIp = ""
)

Write-Host "=== Student Portfolio Platform — Deploy ===" -ForegroundColor Cyan
Write-Host ""

# Get your public IP if not provided
if (-not $MyPublicIp) {
    Write-Host "Detecting your public IP..." -ForegroundColor Yellow
    $MyPublicIp = (Invoke-RestMethod -Uri "https://ifconfig.me/ip" -TimeoutSec 10).Trim()
    Write-Host "Your IP: $MyPublicIp" -ForegroundColor Green
}

# Prompt for VM password
$vmPassword = Read-Host -Prompt "Enter VM admin password (min 12 chars, uppercase+lowercase+number+special)" -AsSecureString

# Create resource group
Write-Host "`n[1/3] Creating Resource Group: $ResourceGroup..." -ForegroundColor Yellow
az group create --name $ResourceGroup --location $Location --output none

# Deploy Bicep
Write-Host "[2/3] Deploying Bicep template (this takes ~3-5 minutes)..." -ForegroundColor Yellow
$plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($vmPassword)
)

az deployment group create `
    --resource-group $ResourceGroup `
    --template-file "$PSScriptRoot\main.bicep" `
    --parameters myPublicIp=$MyPublicIp vmAdminPassword=$plainPassword `
    --output table

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n[3/3] Deployment successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "=== Next Steps ===" -ForegroundColor Cyan
    Write-Host "1. Get VM private IP from deployment outputs"
    Write-Host "2. RDP into VM (use Azure Bastion or add temp public IP for setup)"
    Write-Host "3. Run scripts\setup-db.ps1 on the VM to install PostgreSQL"
    Write-Host "4. Deploy Function App code: func azure functionapp publish <function-app-name>"
    Write-Host "5. Test: curl https://<function-app-name>.azurewebsites.net/api/profile"
    Write-Host ""
    Write-Host "To destroy all resources: .\destroy.ps1" -ForegroundColor Yellow
} else {
    Write-Host "`nDeployment failed. Check errors above." -ForegroundColor Red
}
