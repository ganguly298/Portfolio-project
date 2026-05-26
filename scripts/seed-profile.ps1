param(
    [string]$ResourceGroup = "rg-portfolio-dev",
    [string]$FunctionApp = "portfolio-func-svbzwtaqldjri"
)

$az = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'

Write-Host "[1/4] Reading storage account name from function app settings..." -ForegroundColor Cyan
$conn = & $az functionapp config appsettings list --name $FunctionApp --resource-group $ResourceGroup --query "[?name=='TABLE_STORAGE_CONNECTION'].value" -o tsv
if (-not $conn) {
    Write-Host "TABLE_STORAGE_CONNECTION not set on function app." -ForegroundColor Red
    exit 1
}
if ($conn -notmatch 'AccountName=([^;]+)') {
    Write-Host "Could not parse AccountName from connection string." -ForegroundColor Red
    exit 1
}
$storageAccount = $Matches[1]
Write-Host "Storage account: $storageAccount" -ForegroundColor Green

Write-Host "[2/4] Fetching storage account key..." -ForegroundColor Cyan
$storageKey = & $az storage account keys list --resource-group $ResourceGroup --account-name $storageAccount --query "[0].value" -o tsv
if (-not $storageKey) {
    Write-Host "Failed to get storage key." -ForegroundColor Red
    exit 1
}

Write-Host "[3/4] Ensuring 'profiles' table exists..." -ForegroundColor Cyan
& $az storage table create --name profiles --account-name $storageAccount --account-key $storageKey | Out-Null

Write-Host "[4/4] Inserting/replacing profile entity..." -ForegroundColor Cyan
# NOTE: az CLI strips inner quotes unless we escape them AND wrap the whole
# value in double quotes. Otherwise skills becomes "[Azure,Bicep,...]" which
# is invalid JSON and JSON.parse() in the function will throw.
$entity = [ordered]@{
    PartitionKey = 'portfolio'
    RowKey       = 'saurav'
    name         = 'Saurav Ganguly'
    title        = 'Cloud Engineering Student'
    about        = 'Learning cloud infrastructure with Azure for Students. Building serverless APIs and managing IaC with Bicep.'
    skills       = '["Azure","Bicep","IaC","DevOps","Python","Node.js"]'
    github       = 'https://github.com/ganguly298'
    linkedin     = ''
}
$pairs = foreach ($k in $entity.Keys) {
    $v = $entity[$k] -replace '"','\"'
    "$k=`"$v`""
}
$argList = @(
    'storage','entity','insert',
    '--account-name', $storageAccount,
    '--account-key',  $storageKey,
    '--table-name',   'profiles',
    '--if-exists',    'replace',
    '--entity'
) + $pairs
& $az @argList

if ($LASTEXITCODE -eq 0) {
    Write-Host "Seed complete." -ForegroundColor Green
    Write-Host "Testing API..." -ForegroundColor Cyan
    try {
        $r = Invoke-RestMethod "https://$FunctionApp.azurewebsites.net/api/profile"
        $r | ConvertTo-Json -Depth 5
    } catch {
        Write-Host "API call failed: $_" -ForegroundColor Red
    }
} else {
    Write-Host "Entity insert failed (exit $LASTEXITCODE)." -ForegroundColor Red
}
