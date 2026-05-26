# Student Portfolio Platform — Azure Bicep IaC Project

> A beginner-to-intermediate Infrastructure as Code project using Azure for Students.  
> Total cost: **< $0.10** for a full deploy → test → destroy cycle.

## 🏗️ Architecture: The Building Metaphor

```
┌─────────────────────────────────────────────────────────────┐
│  🧱 THE WALL (Azure VNet: 10.0.0.0/16)                     │
│                                                             │
│  ┌─────────────────────┐    ┌─────────────────────────┐    │
│  │ 🚪 ROOM A           │    │ 🚪 ROOM B               │    │
│  │ (subnet-vm)         │    │ (subnet-functions)       │    │
│  │ 10.0.1.0/24         │    │ 10.0.2.0/24             │    │
│  │                     │    │                          │    │
│  │  Windows 11 VM      │    │  Azure Function App      │    │
│  │  PostgreSQL DB       │    │  (API Layer)            │    │
│  │  NO public IP        │    │  VNet integrated        │    │
│  │                     │    │                          │    │
│  │  🛡️ Security Guard   │    │                          │    │
│  │  (NSG)              │◄───┤  THE HANDSHAKE           │    │
│  │  ✅ 5432 from Room B │    │  (internal traffic)      │    │
│  │  ✅ 3389 from YOUR IP│    │                          │    │
│  │  ❌ Deny all else    │    │                          │    │
│  └─────────────────────┘    └─────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                                        ▲
                              [Static Web App] ← 🌐 User
```

## 📋 Resources Deployed

| Resource | Purpose | Cost |
|----------|---------|------|
| Virtual Network + 2 Subnets | The Wall — network isolation | Free |
| NSG | Security Guard — traffic rules | Free |
| Windows 11 Pro VM (B2s_v2) | Legacy DB host (PostgreSQL) | ~$0.05/hr |
| Key Vault | Secrets management | Free |
| Storage Account | Functions backend | ~$0.01 |
| Azure Functions (Consumption) | Modern API layer | Free tier |
| Static Web App (Free) | Frontend hosting | Free |
| Logic App (Consumption) | Contact form automation | Free |
| Application Insights | Monitoring | Free (5 GB) |

## 🚀 Quick Start

### Prerequisites
- Azure CLI installed (`az --version`)
- Azure for Students subscription active
- Node.js 18+ (for Function App development)

### Deploy

```powershell
cd student-portfolio-platform
.\deploy.ps1
```

The script will:
1. Detect your public IP (for RDP access)
2. Ask for a VM admin password
3. Create the resource group
4. Deploy all Bicep resources (~3-5 minutes)

### Setup the VM (one-time)

1. RDP into the VM using your whitelisted IP
2. Run `scripts\setup-db.ps1` to install PostgreSQL and seed data
3. Verify: PostgreSQL running on port 5432

### Test the Handshake

```powershell
# Call the Function App API
curl https://<function-app-name>.azurewebsites.net/api/profile
```

Expected response:
```json
{
  "success": true,
  "data": {
    "name": "Saurav Ganguly",
    "title": "Cloud Engineering Student",
    "skills": ["Azure", "Bicep", "IaC", "DevOps", "Python", "PostgreSQL", "Terraform"]
  }
}
```

### Destroy (stop charges)

```powershell
.\destroy.ps1
```

## 📂 Project Structure

```
student-portfolio-platform/
├── main.bicep                  # Root orchestrator
├── modules/
│   ├── network.bicep           # The Wall (VNet + subnets)
│   ├── nsg.bicep               # The Security Guard (NSG rules)
│   ├── vm.bicep                # Legacy System (Win11 VM)
│   ├── keyVault.bicep          # The Safe (secrets)
│   ├── storage.bicep           # Storage Account
│   ├── functionApp.bicep       # Modern API (Functions)
│   ├── staticWebApp.bicep      # Frontend hosting
│   ├── logicApp.bicep          # Contact form notifier
│   └── monitoring.bicep        # App Insights
├── parameters/
│   └── dev.bicepparam          # Environment parameters
├── src/
│   ├── api/                    # Azure Functions code
│   └── frontend/               # Static Web App (HTML/CSS/JS)
├── scripts/
│   └── setup-db.ps1            # VM database setup script
├── deploy.ps1                  # One-click deploy
├── destroy.ps1                 # One-click cleanup
└── README.md                   # This file
```

## 🎓 Bicep Concepts Covered

| Concept | Where |
|---------|-------|
| `param` / `var` / `output` | All files |
| `module` | main.bicep → 9 modules |
| `@secure()` decorator | Passwords |
| `@description()` decorator | Documentation |
| `uniqueString()` | Globally unique names |
| Managed Identity | Function App → Key Vault |
| VNet Integration | Function App → subnet delegation |
| Key Vault references | `@Microsoft.KeyVault(...)` in app settings |
| Auto-shutdown schedule | DevTestLab schedules |
| NSG rules | Priority-based security |
| Resource dependencies | Implicit via symbolic names |

## ⚠️ Important Notes

- **Auto-shutdown** is enabled at 23:00 IST — the VM stops automatically to save credit
- **No public IP on VM** — you access it only via RDP from your whitelisted IP
- **Delete when done** — run `destroy.ps1` to remove all resources and stop charges
- **VM password** — stored in Key Vault, never hardcoded in Bicep outputs

## 💰 Credit Impact

| Scenario | Estimated Cost |
|----------|---------------|
| Deploy + test + destroy in 1 hour | < $0.10 |
| Leave VM running 8 hours | ~$0.40 |
| Forgot to destroy (1 day, with auto-shutdown) | ~$0.50 |
| Forgot to destroy (1 day, NO auto-shutdown) | ~$1.20 |

## 📚 References

- [Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Azure for Students](https://azure.microsoft.com/en-us/pricing/offers/ms-azr-0170p/)
- [Azure Functions VNet Integration](https://learn.microsoft.com/en-us/azure/azure-functions/functions-networking-options)
