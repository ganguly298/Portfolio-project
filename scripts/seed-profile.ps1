param(
    [string]$ResourceGroup = "rg-portfolio-dev",
    [string]$StorageAccount,
    [string]$FunctionApp
)

$az = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'

if (-not $StorageAccount) {
    # Fall back to reading STORAGE_ACCOUNT_NAME app setting from the function app.
    if (-not $FunctionApp) {
        Write-Host "Provide -StorageAccount or -FunctionApp." -ForegroundColor Red
        exit 1
    }
    $StorageAccount = & $az functionapp config appsettings list --name $FunctionApp --resource-group $ResourceGroup --query "[?name=='STORAGE_ACCOUNT_NAME'].value" -o tsv
    if (-not $StorageAccount) {
        Write-Host "STORAGE_ACCOUNT_NAME not set on function app." -ForegroundColor Red
        exit 1
    }
}

Write-Host "[1/3] Fetching storage account key for $StorageAccount..." -ForegroundColor Cyan
$storageKey = & $az storage account keys list --resource-group $ResourceGroup --account-name $StorageAccount --query "[0].value" -o tsv
if (-not $storageKey) {
    Write-Host "Failed to get storage key." -ForegroundColor Red
    exit 1
}

Write-Host "[2/3] Ensuring 'profiles' table exists..." -ForegroundColor Cyan
& $az storage table create --name profiles --account-name $StorageAccount --account-key $storageKey | Out-Null

Write-Host "[3/3] Inserting/replacing profile entity..." -ForegroundColor Cyan
$entity = [ordered]@{
    PartitionKey = 'portfolio'
    RowKey       = 'saurav'
    name         = 'Saurav Ganguly'
    title        = 'Cloud Engineering Student'
    about        = 'Learning cloud infrastructure with Azure for Students. Building serverless APIs and managing IaC with Bicep.'
    skills       = '["Azure","Bicep","IaC","DevOps","Python","Node.js"]'
    github       = 'https://github.com/ganguly298'
    linkedin     = 'https://www.linkedin.com/in/saurav-ganguly-8b1542279'
}
$pairs = foreach ($k in $entity.Keys) {
    $v = $entity[$k] -replace '"','\"'
    "$k=`"$v`""
}
$argList = @(
    'storage','entity','insert',
    '--account-name', $StorageAccount,
    '--account-key',  $storageKey,
    '--table-name',   'profiles',
    '--if-exists',    'replace',
    '--entity'
) + $pairs
& $az @argList

if ($LASTEXITCODE -eq 0) {
    Write-Host "Seed complete." -ForegroundColor Green
    if ($FunctionApp) {
        Write-Host "Testing API..." -ForegroundColor Cyan
        try {
            $r = Invoke-RestMethod "https://$FunctionApp.azurewebsites.net/api/profile"
            $r | ConvertTo-Json -Depth 5
        } catch {
            Write-Host "API call failed: $_" -ForegroundColor Red
        }
    }
} else {
    Write-Host "Entity insert failed (exit $LASTEXITCODE)." -ForegroundColor Red
}
