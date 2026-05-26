# ============================================================
# destroy.ps1 — One-click cleanup (deletes entire resource group)
# Stops ALL charges immediately
# ============================================================

param(
    [string]$ResourceGroup = "rg-portfolio-dev"
)

Write-Host "=== Student Portfolio Platform — Destroy ===" -ForegroundColor Red
Write-Host ""
Write-Host "This will PERMANENTLY delete:" -ForegroundColor Yellow
Write-Host "  - Resource Group: $ResourceGroup"
Write-Host "  - ALL resources inside it (Storage, Function App, Key Vault, Logic App, App Insights)"
Write-Host ""

$confirm = Read-Host "Type 'yes' to confirm destruction"

if ($confirm -eq 'yes') {
    Write-Host "`nDeleting resource group (this takes 2-5 minutes)..." -ForegroundColor Yellow
    az group delete --name $ResourceGroup --yes --no-wait
    Write-Host "Deletion initiated! Resources will be removed in the background." -ForegroundColor Green
    Write-Host "No further charges will accrue once deletion completes." -ForegroundColor Green
} else {
    Write-Host "Cancelled. No resources were deleted." -ForegroundColor Cyan
}
