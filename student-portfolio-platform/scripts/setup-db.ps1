# ============================================================
# setup-db.ps1 — Run this on the VM via RDP
# Installs PostgreSQL and seeds the portfolio database
# ============================================================

Write-Host "=== Student Portfolio Platform — VM Database Setup ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Download and install PostgreSQL
$pgVersion = "16"
$installerUrl = "https://get.enterprisedb.com/postgresql/postgresql-${pgVersion}.4-1-windows-x64.exe"
$installerPath = "$env:TEMP\postgresql-installer.exe"

Write-Host "[1/4] Downloading PostgreSQL $pgVersion..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing

Write-Host "[2/4] Installing PostgreSQL (this takes a few minutes)..." -ForegroundColor Yellow
Start-Process -FilePath $installerPath -ArgumentList @(
    "--mode", "unattended",
    "--unattendedmodeui", "none",
    "--superpassword", "REPLACE_WITH_YOUR_DB_PASSWORD",
    "--serverport", "5432",
    "--prefix", "C:\PostgreSQL",
    "--datadir", "C:\PostgreSQL\data"
) -Wait -NoNewWindow

# Add PostgreSQL to PATH
$env:PATH += ";C:\PostgreSQL\bin"
[Environment]::SetEnvironmentVariable("PATH", $env:PATH, "Machine")

Write-Host "[3/4] Configuring PostgreSQL to listen on all interfaces..." -ForegroundColor Yellow

# Allow connections from the VNet (10.0.0.0/16)
$pgHbaPath = "C:\PostgreSQL\data\pg_hba.conf"
Add-Content -Path $pgHbaPath -Value "`nhost    all    all    10.0.0.0/16    md5"

# Listen on all interfaces
$pgConfPath = "C:\PostgreSQL\data\postgresql.conf"
(Get-Content $pgConfPath) -replace "#listen_addresses = 'localhost'", "listen_addresses = '*'" |
    Set-Content $pgConfPath

# Restart PostgreSQL service
Restart-Service -Name "postgresql-x64-$pgVersion" -Force

Write-Host "[4/4] Creating portfolio database and seeding data..." -ForegroundColor Yellow

# Create database and table
$sql = @"
CREATE DATABASE portfolio;
\c portfolio
CREATE TABLE profile (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    title VARCHAR(200) NOT NULL,
    about TEXT,
    skills TEXT[]
);

INSERT INTO profile (name, title, about, skills) VALUES (
    'Saurav Ganguly',
    'Cloud Engineering Student',
    'Learning cloud infrastructure with Azure for Students. Building serverless APIs, managing IaC with Bicep, and exploring hybrid-cloud patterns.',
    ARRAY['Azure', 'Bicep', 'IaC', 'DevOps', 'Python', 'PostgreSQL', 'Terraform']
);
"@

$sql | & "C:\PostgreSQL\bin\psql.exe" -U postgres

# Open firewall for port 5432 (internal VNet traffic)
New-NetFirewallRule -DisplayName "PostgreSQL (VNet)" -Direction Inbound -Protocol TCP -LocalPort 5432 -Action Allow | Out-Null

Write-Host ""
Write-Host "=== Setup Complete! ===" -ForegroundColor Green
Write-Host "PostgreSQL is running on port 5432"
Write-Host "Database: portfolio"
Write-Host "The Function App can now connect via VNet private IP"
Write-Host ""
Write-Host "IMPORTANT: Replace 'REPLACE_WITH_YOUR_DB_PASSWORD' above with your actual password" -ForegroundColor Red
