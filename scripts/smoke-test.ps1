#requires -Version 5.1
<#
End-to-end smoke test for the Student Portfolio Platform.
Verifies: resource group, function app state, app settings, storage tables,
seeded profile entity, GET /api/profile, POST /api/contact, and that the
contact row is actually persisted.
#>
param(
    [string]$ResourceGroup = 'rg-portfolio-dev',
    [string]$FunctionApp   = 'portfolio-func-svbzwtaqldjri',
    [string]$StorageAccount = 'portfoliostsvbzwtaqldjri'
)

$az = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'
$ErrorActionPreference = 'Continue'
$pass = 0; $fail = 0

function Check($name, [scriptblock]$test) {
    Write-Host ("[ .. ] " + $name) -NoNewline
    try {
        $ok = & $test
        if ($ok) {
            Write-Host ("`r[ OK ] " + $name) -ForegroundColor Green
            $script:pass++
        } else {
            Write-Host ("`r[FAIL] " + $name) -ForegroundColor Red
            $script:fail++
        }
    } catch {
        Write-Host ("`r[FAIL] " + $name + " :: " + $_.Exception.Message) -ForegroundColor Red
        $script:fail++
    }
}

Write-Host "=== Student Portfolio Platform - Smoke Test ===" -ForegroundColor Cyan
Write-Host "RG : $ResourceGroup"
Write-Host "App: $FunctionApp"
Write-Host "SA : $StorageAccount"
Write-Host ""

# ---------- 1. Resource group exists ----------
Check 'Resource group exists' {
    $rg = & $az group show -n $ResourceGroup --query name -o tsv 2>$null
    $rg -eq $ResourceGroup
}

# ---------- 2. Function App is Running ----------
Check 'Function App state = Running' {
    $state = & $az functionapp show -g $ResourceGroup -n $FunctionApp --query state -o tsv 2>$null
    $state -eq 'Running'
}

# ---------- 3. App settings present ----------
$settings = & $az functionapp config appsettings list --name $FunctionApp --resource-group $ResourceGroup -o json | ConvertFrom-Json
$settingsMap = @{}
foreach ($s in $settings) { $settingsMap[$s.name] = $s.value }

Check 'TABLE_STORAGE_CONNECTION app setting present' {
    $settingsMap.ContainsKey('TABLE_STORAGE_CONNECTION') -and $settingsMap['TABLE_STORAGE_CONNECTION'] -match 'AccountName='
}
Check 'TABLE_STORAGE_CONNECTION points to expected storage account' {
    $settingsMap['TABLE_STORAGE_CONNECTION'] -match "AccountName=$StorageAccount(;|$)"
}
Check 'AzureWebJobsStorage app setting present' {
    $settingsMap.ContainsKey('AzureWebJobsStorage')
}

# ---------- 4. Storage account + tables ----------
$key = & $az storage account keys list -g $ResourceGroup --account-name $StorageAccount --query "[0].value" -o tsv 2>$null
Check 'Storage account key fetched' { [bool]$key }

$tables = & $az storage table list --account-name $StorageAccount --account-key $key --query "[].name" -o tsv 2>$null
Check 'Table "profiles" exists' { $tables -split "`n" -contains 'profiles' }
Check 'Table "contacts" exists' { $tables -split "`n" -contains 'contacts' }

# ---------- 5. Seeded profile entity is valid JSON ----------
$entityJson = & $az storage entity show --account-name $StorageAccount --account-key $key --table-name profiles --partition-key portfolio --row-key saurav -o json 2>$null
$entity = $null
if ($entityJson) { $entity = $entityJson | ConvertFrom-Json }

Check 'Profile entity portfolio/saurav exists' { $null -ne $entity }
Check 'Profile.skills is a valid JSON array string' {
    if (-not $entity) { return $false }
    try { @($entity.skills | ConvertFrom-Json).Count -gt 0 } catch { $false }
}

# ---------- 6. GET /api/profile ----------
$baseUrl = "https://$FunctionApp.azurewebsites.net"
$profile = $null
Check 'GET /api/profile returns 200 + source=table-storage' {
    try {
        $script:profile = Invoke-RestMethod "$baseUrl/api/profile" -Method GET -TimeoutSec 30
        $script:profile.success -eq $true -and $script:profile.source -eq 'table-storage'
    } catch { $false }
}
Check 'GET /api/profile data.skills is an array with items' {
    $script:profile -and $script:profile.data.skills -is [System.Array] -and $script:profile.data.skills.Count -gt 0
}

# ---------- 7. POST /api/contact ----------
$testEmail = "smoke-test-$(Get-Date -Format 'yyyyMMddHHmmss')@example.com"
$body = @{ name='Smoke Test'; email=$testEmail; message='automated smoke test' } | ConvertTo-Json
$contactResp = $null
Check 'POST /api/contact returns success' {
    try {
        $script:contactResp = Invoke-RestMethod "$baseUrl/api/contact" -Method POST -Body $body -ContentType 'application/json' -TimeoutSec 30
        $script:contactResp.success -eq $true
    } catch { $false }
}

# Give Table Storage a moment then verify the row landed
Start-Sleep -Seconds 3
Check 'Contact row persisted in contacts table' {
    $rowsRaw = & $az storage entity query --account-name $StorageAccount --account-key $key --table-name contacts --filter "email eq '$testEmail'" -o json 2>$null
    if (-not $rowsRaw) { return $false }
    $rowsText = ($rowsRaw -join "`n")
    $parsed = $rowsText | ConvertFrom-Json
    @($parsed.items).Count -ge 1
}

# ---------- 8. POST /api/contact validation (missing fields) ----------
Check 'POST /api/contact rejects missing fields with 400' {
    try {
        Invoke-RestMethod "$baseUrl/api/contact" -Method POST -Body '{}' -ContentType 'application/json' -TimeoutSec 30 | Out-Null
        $false
    } catch {
        $_.Exception.Response.StatusCode.value__ -eq 400
    }
}

# ---------- Summary ----------
Write-Host ""
$summaryColor = if ($fail -eq 0) { 'Green' } else { 'Red' }
Write-Host "=== Result: $pass passed, $fail failed ===" -ForegroundColor $summaryColor
if ($profile) {
    Write-Host ""
    Write-Host "Live profile response:" -ForegroundColor Cyan
    $profile | ConvertTo-Json -Depth 5
}
exit $fail
