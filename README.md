# Student Portfolio Platform — Azure Bicep IaC Project

> A beginner-friendly, end-to-end **serverless cloud project** built on Microsoft Azure using **Infrastructure as Code (Bicep)**.  
> Runs entirely on free/consumption tiers — total cost: **~$0.00** with the Azure for Students subscription.

---

## 📖 What is this project?

This project is a tiny but **complete cloud application** for a personal portfolio website. It's designed as a **learning project** — you can read every file, understand every Azure service involved, deploy it to your own subscription in ~5 minutes, play with it, then tear it down so it costs you nothing.

Imagine the backend of a portfolio site like `yourname.dev` — it needs to:

1. **Serve your profile** (name, bio, skills, links) to whoever visits the page.
2. **Accept messages** from a "Contact Me" form and store them safely.
3. **Notify you** when someone gets in touch.
4. **Store secrets** (API keys, passwords) without hard-coding them.
5. **Tell you** when something breaks.

That's exactly what this project builds — using five small Azure services glued together with code.

### What does it actually *do*?

Once deployed, you get a live HTTPS API in the cloud with two endpoints:

| Endpoint | Method | What it does |
|---|---|---|
| `/api/profile` | GET | Returns your portfolio data (name, title, about, skills, links) as JSON. |
| `/api/contact` | POST | Accepts a JSON body `{name, email, message}`, saves it to a database, and notifies a Logic App workflow. |

A frontend (React, plain HTML, anything) could call these two endpoints to power a real portfolio site. No servers to manage, no VMs to patch, no monthly bill.

### What does it *show / teach*?

This project is a hands-on tour of **modern cloud fundamentals**:

- **Infrastructure as Code (IaC)** — your cloud setup lives in Git as `.bicep` files instead of being clicked together in a portal.
- **Serverless compute** — Azure Functions runs your Node.js code only when someone calls the API (you pay per request, not per hour).
- **NoSQL storage** — Azure Table Storage as a tiny, cheap, schemaless database.
- **Secrets management** — Azure Key Vault + Managed Identity, so no passwords ever sit in your code.
- **Workflow automation** — Azure Logic Apps as a low-code "if this, then that" engine.
- **Observability** — Application Insights collects logs and metrics automatically.
- **One-click deploy & destroy** — PowerShell scripts that wire everything up and tear it down.
- **Smoke testing** — an automated end-to-end test that proves your live deployment actually works.

By reading the code and running it, a beginner gets a real feel for how a small production-style cloud system is wired together.

---

## 🧠 Concepts in plain English

If any of the buzzwords below are new, here's the 30-second version:

| Term | Plain-English meaning |
|---|---|
| **Cloud** | Someone else's computers (Microsoft's, in this case) that you rent by the second. |
| **Resource Group** | A folder in Azure that holds all the resources for one project. Delete the folder → delete everything inside → bill stops. |
| **Bicep** | A friendly language for describing Azure resources. You write what you want; Azure makes it real. Replaces clicking around the portal. |
| **IaC (Infrastructure as Code)** | The idea that your cloud setup should be a file in Git, not a memory of clicks. Reproducible, reviewable, versioned. |
| **Serverless** | You write functions; the cloud runs them on demand. You don't manage a server. When nobody calls your API, you pay $0. |
| **Azure Function** | A small piece of code (here, Node.js) that runs in response to an HTTP request. |
| **Table Storage** | A super-cheap NoSQL key/value store. Think "Excel-like rows with a partition + row key". Perfect for tiny apps. |
| **Key Vault** | A secure safe for secrets (passwords, API keys, connection strings). |
| **Managed Identity** | An Azure-provided identity for your app, so it can talk to other Azure services *without* a password. The cloud handles the auth for you. |
| **Logic App** | A visual/JSON-defined workflow. "When X happens, do Y, then Z." Great for notifications, integrations, glue code. |
| **Application Insights** | Auto-collects logs, errors, response times, and request counts from your app. Your "black box recorder". |
| **Consumption / Y1 plan** | A pricing tier where you only pay per execution. Free for the first 1 million calls per month. |

---

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

## 📋 Resources Deployed (what each one is and why it's here)

All five resources live inside one resource group (`rg-portfolio-dev`) in the **Central India** region.

### 1. Storage Account + Table Storage — *the database & function plumbing*
- **What it is:** A general-purpose Azure storage account that hosts two NoSQL tables (`profiles`, `contacts`) and also acts as the required backing store for the Function App runtime.
- **Why it's here:** Table Storage is the cheapest persistent database in Azure (literally fractions of a cent). It stores your portfolio profile and any contact-form submissions.
- **Cost:** ~$0.01/month at hobby scale.

### 2. Azure Functions (Y1 Consumption) — *the API*
- **What it is:** A serverless Node.js app exposing two HTTP endpoints (`GET /api/profile`, `POST /api/contact`).
- **Why it's here:** It's the "brain" — receives HTTP requests, talks to Table Storage, and calls the Logic App. Y1 plan = pay-per-execution.
- **Cost:** Free for the first **1,000,000 executions/month**.

### 3. Key Vault — *the safe*
- **What it is:** A managed secret store. We put one demo secret (`app-secret`) in it during deployment.
- **Why it's here:** Demonstrates the production pattern of keeping secrets out of code/config files. The Function App reads it via a `@Microsoft.KeyVault(...)` reference using its Managed Identity — no password ever touches your source code.
- **Cost:** Free for basic operations.

### 4. Logic App (Consumption) — *the notifier / workflow*
- **What it is:** An HTTP-triggered workflow that the Function App POSTs to whenever a new contact is submitted.
- **Why it's here:** Shows how to extend an app with no-code/low-code automation. Today it just returns `200 OK`; you can easily extend it to send an email, post to Teams/Slack, or call any API.
- **Cost:** Free for the first ~4,000 actions/month.

### 5. Application Insights — *the camera*
- **What it is:** Azure's monitoring and telemetry service.
- **Why it's here:** Captures logs, exceptions, request rates, durations, and dependencies from the Function App automatically. Lets you debug a live system from the Azure portal.
- **Cost:** Free for the first 5 GB of ingested telemetry/month.

**Total cost for deploy → test → destroy: ~$0.00**

---

## 🔁 How a request flows (end-to-end)

**Getting your profile** (`GET /api/profile`):
```
Browser/curl  ──HTTPS──▶  Function App  ──connection string──▶  Table Storage
                              │                                       │
                              └──── reads 'profiles' table ◀──────────┘
                              │
                              └──▶ logs & metrics ──▶ Application Insights
                              │
                              ▼
                         JSON response
```

**Submitting a contact form** (`POST /api/contact`):
```
Browser/curl
   │ JSON {name, email, message}
   ▼
Function App
   ├─▶ writes row into 'contacts' table (Table Storage)
   ├─▶ POSTs payload to Logic App HTTP trigger
   │        └─▶ Logic App workflow runs (extend to email/Teams/etc.)
   ├─▶ telemetry to Application Insights
   ▼
JSON response {success: true, ...}
```

Key Vault sits to the side: at startup, the Function App resolves `APP_SECRET` from Key Vault using its Managed Identity. The secret value is never visible in code or config files.

---

## 🚀 Quick Start

### Prerequisites

- Azure CLI installed (`az --version`) and logged in (`az login`)
- Azure for Students subscription active (`az account set --subscription <id>`)
- PowerShell 5.1+ (Windows) — used by `deploy.ps1` / `destroy.ps1` / `scripts/*`
- *(Optional)* Node.js 18+ and Azure Functions Core Tools (`npm i -g azure-functions-core-tools@4`) — only needed for **local** Function App development. `deploy.ps1` publishes the code via `az` zip-deploy, so they aren't required for cloud deployment.

### Deploy (one command)

```powershell
cd Portfolio-project
.\deploy.ps1
```

The script will:
1. Ask for an app secret (stored in Key Vault)
2. Create the resource group in Central India
3. Deploy all Bicep resources (~2-3 minutes)
4. Package `src/api` and publish it to the Function App (zip-deploy with remote `npm install`)
5. Seed your profile data into Table Storage
6. Print API URLs for testing

### Test the API

Replace `<function-app-name>` with the name printed by `deploy.ps1` (looks like `portfolio-func-xxxxxxxxxxxx`).

```powershell
# Get profile
curl https://<function-app-name>.azurewebsites.net/api/profile

# Submit contact form
curl -X POST https://<function-app-name>.azurewebsites.net/api/contact `
  -H "Content-Type: application/json" `
  -d '{"name":"Test User","email":"test@example.com","message":"Hello from curl!"}'
```

**Example `GET /api/profile` response:**
```json
{
  "success": true,
  "source": "table-storage",
  "data": {
    "name": "Saurav Ganguly",
    "title": "Cloud Engineering Student",
    "about": "Learning cloud infrastructure with Azure for Students...",
    "skills": ["Azure", "Bicep", "IaC", "DevOps", "Python", "Node.js"],
    "github": "https://github.com/ganguly298",
    "linkedin": ""
  }
}
```

**Example `POST /api/contact` response:**
```json
{
  "success": true,
  "message": "Thank you Test User, your message has been received!"
}
```

If the `profiles` table hasn't been seeded yet, the API gracefully falls back to default data and returns `"source": "default"`.

### Deploy Function Code (manual / re-deploy only)

`deploy.ps1` already publishes the function code. Use this only if you change `src/api` and want to re-deploy without re-running Bicep:

```powershell
cd src\api
func azure functionapp publish <function-app-name>
```

### Smoke test (end-to-end validation)

```powershell
.\scripts\smoke-test.ps1
```

Verifies the RG, Function App state, app settings, tables, seeded profile, `GET /api/profile`, `POST /api/contact` (including persistence and 400-validation).

### Destroy (stop all charges)

```powershell
.\destroy.ps1
```

## 📂 Project Structure

```
Portfolio-project/
├── main.bicep                  # Root orchestrator (5 modules)
├── modules/
│   ├── storage.bicep           # Storage Account + Table Storage tables
│   ├── functionApp.bicep       # Function App (Y1, no VNet)
│   ├── keyVault.bicep          # Key Vault for secrets
│   ├── logicApp.bicep          # Logic App (contact notifier)
│   └── monitoring.bicep        # Application Insights
├── parameters/
│   └── dev.bicepparam          # Environment parameters (reference; deploy.ps1 passes params inline)
├── src/api/
│   ├── host.json               # Functions host config
│   ├── package.json            # Node.js dependencies (@azure/data-tables)
│   ├── GetProfile/             # GET /api/profile
│   │   ├── function.json
│   │   └── index.js
│   └── SubmitContact/          # POST /api/contact
│       ├── function.json
│       └── index.js
├── scripts/
│   ├── seed-profile.ps1        # Seeds the 'profiles' table (called by deploy.ps1)
│   └── smoke-test.ps1          # End-to-end validation of the deployed stack
├── deploy.ps1                  # One-click deploy + publish code + seed data
├── destroy.ps1                 # One-click cleanup (deletes the resource group)
├── azure-for-students-plan.md  # Cost/credit planning notes
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

> 💡 The Azure for Students subscription gives you **$100 in free credit** for 12 months and doesn't require a credit card. See [`azure-for-students-plan.md`](./azure-for-students-plan.md) for the full breakdown of what's included.

---

## 🧪 If something breaks (common gotchas)

| Symptom | Likely cause / fix |
|---|---|
| `deploy.ps1` errors with "Please run 'az login'" | Run `az login`, then re-run the script. |
| Deployment succeeds but `/api/profile` returns `"source": "default"` | The seed step didn't run or hadn't finished — re-run `scripts\seed-profile.ps1`. |
| `func: command not found` | You only need Functions Core Tools for *local* development. `deploy.ps1` doesn't use it. |
| Function App returns 500 errors | Open the resource in the Azure portal → **Application Insights** → **Failures**. Look at the latest exception. |
| Smoke test fails on "Contact row persisted" | Table writes are eventually consistent; the test waits 3s. Re-run if you see a transient miss. |
| `az` CLI not on `PATH` in scripts | The PowerShell scripts use the default Windows install path (`C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd`). Edit the `$az` variable if yours differs. |
| Key Vault deployment fails with soft-delete name conflict | Names are reused across deletes for 7 days. Wait, purge the vault, or change `projectName`. |

---

## 🎯 What you'll learn by reading & running this

By the time you've deployed, tested, and destroyed this project once, you'll have hands-on experience with:

- ✅ Writing and deploying **Bicep modules** that compose a real multi-service app
- ✅ Using **Azure CLI** (`az`) to log in, deploy templates, and inspect resources
- ✅ The **serverless model** with Azure Functions (HTTP triggers, app settings, env vars)
- ✅ A simple **NoSQL data model** in Azure Table Storage (partition key / row key)
- ✅ Storing and **referencing secrets** from Key Vault using Managed Identity — no passwords in code
- ✅ Building a tiny **HTTP-triggered Logic App workflow**
- ✅ Reading **logs and exceptions** in Application Insights
- ✅ Writing **PowerShell automation** for deploy / seed / smoke-test / destroy
- ✅ Cost-aware cloud development on a **student budget**

That's the foundation for almost any real cloud project — scaled down to something you can fully understand in an afternoon.

---

## 📚 References

- [Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Azure Functions - Node.js Developer Guide](https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-node)
- [Azure Table Storage](https://learn.microsoft.com/en-us/azure/storage/tables/table-storage-overview)
- [Key Vault References in App Settings](https://learn.microsoft.com/en-us/azure/app-service/app-service-key-vault-references)
- [Azure for Students](https://azure.microsoft.com/en-us/pricing/offers/ms-azr-0170p/)
