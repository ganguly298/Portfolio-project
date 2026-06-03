# `functionApp.bicep` — The Story of the Function App

> A Restaurant That Never Sleeps

Imagine your Function App is a **tiny pop-up restaurant** inside the giant Azure shopping mall. It only opens when a customer walks in, cooks one dish, serves it, and closes again until the next customer arrives. That's the magic of **Flex Consumption** — you pay only for the seconds the kitchen is actually cooking.

---

## Scene 1 — Renting the kitchen (the hosting plan)

```bicep
resource hostingPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${functionAppName}-plan'
  location: location
  kind: 'functionapp'
  sku: { name: 'FC1'; tier: 'FlexConsumption' }
  properties: { reserved: true }
}
```

Before the chef can cook, you need a **kitchen** to put the stove in. In Azure that's a `serverfarms` resource — also called an **App Service Plan** or **hosting plan**.

- `sku.name: 'FC1'` and `tier: 'FlexConsumption'` → "Rent me the Flex Consumption kitchen." Pay-per-second, auto-scales from zero.
- `reserved: true` → "It's a **Linux** kitchen, not Windows." (Microsoft's old, weird way of saying Linux.)
- `kind: 'functionapp'` → "This kitchen is for Functions, not regular web apps."

Think of it as the lease for the kitchen space. The stove (your code) goes on top of it next.

---

## Scene 2 — Building the restaurant on top of the kitchen

```bicep
resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: { type: 'SystemAssigned' }
  ...
}
```

- `kind: 'functionapp,linux'` → "It's a Function App, and the kitchen below is Linux." Must match the plan.
- `identity: { type: 'SystemAssigned' }` → Gives the restaurant an **employee ID card** (a managed identity / service principal) so it can later open locked cupboards (Key Vault, Storage) without carrying physical keys.
- `serverFarmId: hostingPlan.id` → "Plug me into the kitchen we just rented."

---

## Scene 3 — Where does the recipe book come from? (`functionAppConfig.deployment`)

```bicep
functionAppConfig: {
  deployment: {
    storage: {
      type: 'blobContainer'
      value: deploymentStorageContainerUrl
      authentication: { type: 'SystemAssignedIdentity' }
    }
  }
}
```

The most special part of Flex Consumption.

Old Functions had code on a hard disk attached to the server (a "file share"). Flex Consumption threw that away.

Now the recipe book (your zipped code) lives in a **blob container** in Storage. Every time the kitchen wakes up, Azure says:

> "Hey storage cupboard, give me the latest zip. I'll unpack it and start cooking."

- `type: 'blobContainer'` → "Code lives in a blob container."
- `value: deploymentStorageContainerUrl` → "Here's its full URL."
- `authentication: { type: 'SystemAssignedIdentity' }` → "Use my employee ID card to fetch it — **no storage key, no SAS token, nothing typed in.**"

This is why your project never has a single password in it. `deploy.ps1` uploads a fresh zip to that container every time — restocking the recipe book.

---

## Scene 4 — How big can the kitchen get? (`scaleAndConcurrency`)

```bicep
scaleAndConcurrency: {
  maximumInstanceCount: 100
  instanceMemoryMB: 2048
}
```

- `maximumInstanceCount: 100` → "If 100 customers walk in at once, clone the kitchen up to 100 times in parallel."
- `instanceMemoryMB: 2048` → "Give each cloned kitchen 2 GB of RAM."

When no one is around, instances drop back to zero. **You pay nothing while idle.**

---

## Scene 5 — What language does the chef speak? (`runtime`)

```bicep
runtime: { name: 'node'; version: '20' }
```

Self-explanatory: "Chef speaks Node.js 20." (Python, .NET, Java, PowerShell are also valid.)

---

## Scene 6 — The order slips pinned to the wall (`appSettings`)

Every restaurant has a clipboard with notes for the chef. In Function Apps that clipboard is **app settings** — environment variables that show up in your code as `process.env.SOMETHING`.

| Note | Translation |
|---|---|
| `AzureWebJobsStorage__accountName` + `__credential = managedidentity` | "Don't carry storage keys. Use your badge to talk to storage." The double underscore is the .NET/Functions convention for "sub-property." |
| `APPINSIGHTS_INSTRUMENTATIONKEY` | "Whisper every order and every mistake into this microphone (Application Insights), so we can review the day later." |
| `STORAGE_ACCOUNT_NAME` | A plain string your **own code** reads to know which storage account to write contact-form entries into. |
| `APP_SECRET = @Microsoft.KeyVault(VaultName=...;SecretName=app-secret)` | The **magic teleporter string**. At startup, the platform sees this marker, uses the badge to open the vault, fetches the real secret, and pastes it into `process.env.APP_SECRET`. By the time your code reads it, it's already the real value. |
| `LOGIC_APP_CALLBACK_URL` | "When a contact form is submitted, POST a JSON message to *this* URL — it pings the Logic App which then logs / sends an email." |

### Two kinds of app settings

| Kind | Who decides the name? | Example |
|---|---|---|
| **Platform-recognized** | Microsoft. The runtime greps for these *exact* spellings. Wrong name → silently doesn't work. | `AzureWebJobsStorage__accountName`, `APPINSIGHTS_INSTRUMENTATIONKEY` |
| **Your own variables** | You. The platform doesn't care; only your code reads them via `process.env.WHATEVER`. | `LOGIC_APP_CALLBACK_URL`, `STORAGE_ACCOUNT_NAME` |

Beginners discover the platform-recognized names from Microsoft Learn docs, Azure-Samples GitHub repos, or by deploying a sample via the portal wizard and clicking **Export template**. Bicep IntelliSense (Ctrl+Space) autocompletes resource properties but **not** the strings inside `appSettings`.

---

## Scene 7 — Locking the doors (`siteConfig`)

```bicep
siteConfig: {
  ftpsState:    'Disabled'
  minTlsVersion:'1.2'
  cors: { allowedOrigins: allowedOrigins }
}
```

- `ftpsState: 'Disabled'` → "No FTP back door."
- `minTlsVersion: '1.2'` → "Only modern HTTPS."
- `cors.allowedOrigins` → A **guest list at the front door**. Browsers block any website from calling this API unless its origin is on this list. `deploy.ps1` runs `az functionapp cors add` to add the live `$web` frontend URL to the list.

And at the top:

```bicep
httpsOnly: true
```

> "Refuse plain HTTP. Anything that isn't encrypted gets redirected."

---

## Scene 8 — The receipt at the bottom (`output`s)

```bicep
output functionAppUrl         string = 'https://${functionApp.properties.defaultHostName}'
output functionAppName        string = functionApp.name
output functionAppPrincipalId string = functionApp.identity.principalId
```

Three sticky notes after Bicep finishes:

1. The public URL of the API (used for smoke tests and `config.js`).
2. The Function App name (used for zip upload, CORS, etc.).
3. The employee badge ID — passed into the role-assignment modules so the badge unlocks the right cupboards.

---

## The 5-Second Mental Model

1. **Rent a kitchen** → `hostingPlan` with `FC1` + `FlexConsumption` + `reserved: true` (Linux pay-per-second).
2. **Build the restaurant on it** → `functionApp` with `kind: 'functionapp,linux'` + `identity: SystemAssigned` (gets a badge).
3. **Stock the recipe book from a blob container, using the badge instead of keys** → `functionAppConfig.deployment.storage` + `authentication: SystemAssignedIdentity`. **No passwords stored anywhere.**
4. **Pin notes on the clipboard** → `appSettings` give the chef config, telemetry keys, and the `@Microsoft.KeyVault(...)` teleporter string.
5. **Lock the doors** → `httpsOnly`, `ftpsState: Disabled`, `minTlsVersion: 1.2`, `cors.allowedOrigins`.
6. **Hand back three sticky notes** → URL, name, principalId. The principalId then flows into role assignments giving the badge actual unlocking power.
