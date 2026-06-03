# `storage.bicep` — The Story of the Storage Account

> The Row of Filing Cabinets That Also Hosts the Shop Window

A single **storage account** in Azure is surprisingly versatile — it's three different storage services under one roof, plus a free static-website feature. Your project uses **all three** services from the same account, which saves money and simplifies permissions.

---

## Scene 1 — The building (`storageAccount`)

```bicep
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-04-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: { name: 'Standard_LRS' }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowSharedKeyAccess: true
  }
}
```

| Line | Story translation |
|---|---|
| `kind: 'StorageV2'` | The modern, general-purpose account type that supports all four services (Blob, Queue, Table, File). Always pick this unless you have a reason not to. |
| `sku.name: 'Standard_LRS'` | "**L**ocally **R**edundant **S**torage." 3 copies inside one data centre. Cheapest tier. For a portfolio it's perfect. |
| `supportsHttpsTrafficOnly: true` | Refuse plain HTTP. |
| `minimumTlsVersion: 'TLS1_2'` | Reject old/weak TLS. |
| `allowSharedKeyAccess: true` | **Deliberate compromise.** The data plane is accessed via managed identity at runtime, but the **static-website CLI** and the **seed script** still need the account key. Leaving this on keeps `deploy.ps1` simple. In production you'd flip it off and use AAD-only auth for everything. |

---

## Scene 2 — The three sub-services

Inside this one building are three independent storage services. Each is a separate Bicep child resource:

### a) Blob service + the deployment container

```bicep
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-04-01' = {
  parent: storageAccount
  name: 'default'
}

resource deploymentContainer '.../containers@2023-04-01' = {
  parent: blobService
  name: deploymentContainerName    // 'deployment-package'
  properties: { publicAccess: 'None' }
}
```

- The `default` blob service is mandatory paperwork — every storage account has exactly one, always named `default`.
- The `deployment-package` container is where `deploy.ps1` uploads your zipped Function App code. Flex Consumption pulls it from here on cold start.
- `publicAccess: 'None'` → blobs are not anonymously readable. Only callers with valid AAD tokens (or the account key) can read them.

> **The `$web` container is NOT created here.** It's created automatically the first time `az storage blob service-properties update --static-website` runs in `deploy.ps1`. That's a quirk of the static-website feature — you enable it via a data-plane CLI call, not via Bicep.

### b) Table service + your two tables

```bicep
resource tableService '.../tableServices@2023-04-01' = { parent: storageAccount; name: 'default' }

resource profileTable '.../tables@2023-04-01' = { parent: tableService; name: 'profiles' }
resource contactTable '.../tables@2023-04-01' = { parent: tableService; name: 'contacts' }
```

- `profiles` → seeded with one row (`PartitionKey='portfolio'`, `RowKey='saurav'`) by `scripts/seed-profile.ps1`. Read by `GetProfile/index.js`.
- `contacts` → starts empty. Each form submission becomes one row, written by `SubmitContact/index.js`.

Creating tables in Bicep ensures they exist *before* the seed script tries to write to them — no race conditions.

### c) Queue service (implicit)

There's no explicit `queueService` in this file. The Functions runtime auto-creates the queues it needs (`webjobs-blobtrigger-poison`, etc.) the first time it starts, because the storage-role-assignment module already gave it `Storage Queue Data Contributor`. Bicep doesn't need to predeclare them.

---

## Scene 3 — The outputs (sticky notes)

```bicep
output storageAccountName        string = storageAccount.name
output storageAccountId          string = storageAccount.id
output staticWebsiteUrl          string = storageAccount.properties.primaryEndpoints.web
output blobEndpoint              string = storageAccount.properties.primaryEndpoints.blob
output tableEndpoint             string = storageAccount.properties.primaryEndpoints.table
output deploymentContainerName   string = deploymentContainer.name
output deploymentContainerUrl    string = '${...primaryEndpoints.blob}${deploymentContainer.name}'
```

These outputs are the wires that connect everything:

| Output | Used by |
|---|---|
| `storageAccountName` | Function App app settings (`AzureWebJobsStorage__accountName`, `STORAGE_ACCOUNT_NAME`), plus `deploy.ps1` for static-website enable + uploads. |
| `staticWebsiteUrl` | Becomes the public frontend URL; piped into Function App CORS allowlist. |
| `deploymentContainerUrl` | Passed into `functionApp.bicep` as `deploymentStorageContainerUrl` — the Flex Consumption "where is my zip?" pointer. |
| `tableEndpoint` | Reference for `GetProfile`/`SubmitContact` to know which table endpoint to hit (though they actually construct it from `STORAGE_ACCOUNT_NAME` themselves). |

---

## Scene 4 — Why one account for everything?

You *could* have one storage account for the Function App's internal `AzureWebJobsStorage`, another for the deployment package, another for tables, another for the static website. People do that in enterprise. But:

- **Cheaper** — storage accounts are free, but managing four of them means four sets of RBAC.
- **Simpler** — one set of role assignments covers everything.
- **Within Azure for Students quota** — fewer resources to track.

The downside: noisy-neighbor risk. If your contacts table suddenly grows huge it could affect deployment uploads. Not a concern at portfolio scale.

---

## The 5-Second Mental Model

1. **One `StorageV2` + `Standard_LRS` account** holds everything. Cheapest, most flexible.
2. **Blob service + `deployment-package` container** → Flex Consumption pulls the app zip from here. The `$web` container is created later by `deploy.ps1`, not Bicep.
3. **Table service + `profiles` + `contacts` tables** → your application data. Pre-created so the seed script never races.
4. **Queue service is implicit** — Functions runtime makes its own queues on first start.
5. **`allowSharedKeyAccess: true`** is a deliberate compromise so the static-website CLI + seed script work. Runtime data access still uses managed identity.
6. **Outputs are wires** — `storageAccountName`, `staticWebsiteUrl`, `deploymentContainerUrl` flow into Function App, CORS, and frontend `config.js` via `deploy.ps1`.
