# Student Portfolio Platform — Azure Bicep IaC Project

> A beginner-to-intermediate serverless project using Azure for Students.  
> Total cost: **~$0.00** (all services on free/consumption tier).

## 🏗️ Architecture

```
┌────────────────────────────────────────────────────────┐
│  Resource Group (rg-portfolio-dev) — Central India      │
│                                                        │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────┐  │
│  │ Function App │──▶│ Table Storage │   │ Key Vault│  │
│  │ (Y1 / Free) │   │ (profiles +  │   │ (secrets)│  │
│  │ GET /profile │   │  contacts)   │   └──────────┘  │
│  │ POST /contact│   └──────────────┘                  │
│  └──────┬───────┘                                      │
│         │            ┌──────────────┐   ┌──────────┐  │
│         └───────────▶│  Logic App   │   │App Insight│  │
│                      │ (Notifier)   │   │(Monitor) │  │
│                      └──────────────┘   └──────────┘  │
└────────────────────────────────────────────────────────┘
                    ▲
                    │ HTTPS
                🌐 User / curl / Postman
```

## 📋 Resources Deployed

| Resource | Purpose | Cost |
|----------|---------|------|
| Storage Account + Table Storage | Functions backend + NoSQL database | ~$0.01 |
| Azure Functions (Y1 Consumption) | REST API (2 endpoints) | Free (1M exec/month) |
| Key Vault | Secrets management | Free (basic ops) |
| Logic App (Consumption) | Contact form automation | Free (first 4K actions) |
| Application Insights | Monitoring & diagnostics | Free (5 GB/month) |

**Total cost for deploy → test → destroy: ~$0.00**

## 🚀 Quick Start

### Prerequisites

- Azure CLI installed (`az --version`)
- Azure for Students subscription active
- Node.js 18+ (for local Function App development)
- Azure Functions Core Tools (`npm i -g azure-functions-core-tools@4`)

### Deploy (one command)

```powershell
cd student-portfolio-platform
.\deploy.ps1
```

The script will:
1. Ask for an app secret (stored in Key Vault)
2. Create the resource group in Central India
3. Deploy all Bicep resources (~2-3 minutes)
4. Seed your profile data into Table Storage
5. Print API URLs for testing

### Test the API

```powershell
# Get profile
curl https://<function-app-name>.azurewebsites.net/api/profile

# Submit contact form
curl -X POST https://<function-app-name>.azurewebsites.net/api/contact `
  -H "Content-Type: application/json" `
  -d '{"name":"Test User","email":"test@example.com","message":"Hello from curl!"}'
```

### Deploy Function Code

```powershell
cd src\api
func azure functionapp publish <function-app-name>
```

### Destroy (stop all charges)

```powershell
.\destroy.ps1
```

## 📂 Project Structure

```
student-portfolio-platform/
├── main.bicep                  # Root orchestrator (5 modules)
├── modules/
│   ├── storage.bicep           # Storage Account + Table Storage tables
│   ├── functionApp.bicep       # Function App (Y1, no VNet)
│   ├── keyVault.bicep          # Key Vault for secrets
│   ├── logicApp.bicep          # Logic App (contact notifier)
│   └── monitoring.bicep        # Application Insights
├── parameters/
│   └── dev.bicepparam          # Environment parameters
├── src/api/
│   ├── host.json               # Functions host config
│   ├── package.json            # Node.js dependencies
│   ├── GetProfile/             # GET /api/profile
│   │   ├── function.json
│   │   └── index.js
│   └── SubmitContact/          # POST /api/contact
│       ├── function.json
│       └── index.js
├── deploy.ps1                  # One-click deploy + seed data
├── destroy.ps1                 # One-click cleanup
└── README.md
```

## 🎓 Bicep Concepts Covered

| Concept | Where |
|---------|-------|
| `param` / `var` / `output` | All files |
| `module` references | main.bicep → 5 modules |
| `@secure()` decorator | Passwords/secrets |
| `@description()` decorator | Self-documenting IaC |
| `uniqueString()` | Globally unique resource names |
| Managed Identity (`SystemAssigned`) | Function App |
| Key Vault references | `@Microsoft.KeyVault(...)` in app settings |
| Table Storage provisioning | storage.bicep (tables as child resources) |
| Logic App workflow definition | Inline JSON workflow |
| Resource dependencies | Implicit via symbolic names |
| CORS configuration | functionApp.bicep |

## 🔑 How Key Vault Integration Works

1. Bicep deploys Key Vault with RBAC authorization
2. A secret (`app-secret`) is stored during deployment
3. Function App gets a **Managed Identity** (system-assigned)
4. Function App references the secret via: `@Microsoft.KeyVault(VaultName=...;SecretName=app-secret)`
5. At runtime, Azure resolves the reference automatically — no credentials in code!

## 📡 How the Logic App Works

1. User calls `POST /api/contact` on the Function App
2. Function saves the submission to Table Storage (`contacts` table)
3. Function forwards the payload to the Logic App's HTTP trigger
4. Logic App responds with status 200 (can be extended to send emails, Teams messages, etc.)

## 💰 Credit Impact

| Scenario | Cost |
|----------|------|
| Deploy + test + destroy | ~$0.00 |
| Leave running for a week (no traffic) | ~$0.01 |
| 1000 API calls in a day | ~$0.00 (well within free tier) |

## 📚 References

- [Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Azure Functions - Node.js Developer Guide](https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-node)
- [Azure Table Storage](https://learn.microsoft.com/en-us/azure/storage/tables/table-storage-overview)
- [Key Vault References in App Settings](https://learn.microsoft.com/en-us/azure/app-service/app-service-key-vault-references)
- [Azure for Students](https://azure.microsoft.com/en-us/pricing/offers/ms-azr-0170p/)
