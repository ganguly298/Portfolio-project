# `keyVault.bicep` — The Story of the Locked Cupboard Itself

> Where the Secret Lives

You've read `kvRoleAssignment.README.md` — that was about giving the student permission to open the cupboard. This module is about **building the cupboard** in the first place.

---

## Scene 1 — Renting a vault from the bank (`keyVault`)

```bicep
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: kvName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: { family: 'A'; name: 'standard' }
    enableRbacAuthorization: true
    enabledForTemplateDeployment: true
    softDeleteRetentionInDays: 7
  }
}
```

Think of Key Vault as **renting a private safety-deposit box in a bank**. The bank (Azure) handles physical security, multi-region redundancy, HSM hardware, audit logging — you just decide what goes inside and who can open it.

| Property | Story translation |
|---|---|
| `tenantId: subscription().tenantId` | "The bank should only let people from *my* Entra directory request access." Almost always set to your own tenant. |
| `sku: { family: 'A'; name: 'standard' }` | The cheap tier. Software-protected keys, ₹0.03 per 10k operations. The alternative `premium` adds HSM-backed keys for enterprise compliance — overkill here. `family: 'A'` is always `A` for vaults; it's a leftover from when HSM and software-key SKUs had different family codes. |
| `enableRbacAuthorization: true` | **The modern way.** Permissions are granted via Azure RBAC (role assignments) — the same system used everywhere else in Azure. The old way was a separate "access policies" system inside the vault itself. RBAC is simpler, more consistent, easier to audit. **Set this to `true` for any new vault.** |
| `enabledForTemplateDeployment: true` | "Allow ARM/Bicep deployments to reference secrets from inside this vault during a deployment." Needed if other Bicep modules want to read a secret as `keyVault.getSecret(...)` at deploy time. |
| `softDeleteRetentionInDays: 7` | When a vault is deleted, it goes into a "recycle bin" for 7 days before being permanently purged. Soft-delete is **mandatory** in Key Vault — you can't disable it. You only choose how long the bin holds things (7-90 days). 7 is the minimum; we picked it so a fresh redeploy can purge the deleted vault and reuse the same name quickly. That's why `deploy.ps1` has stage 1a — *"purge any soft-deleted vaults matching our prefix before deploying."* |

---

## Scene 2 — Putting the secret inside (`appSecretEntry`)

```bicep
resource appSecretEntry 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'app-secret'
  properties: { value: appSecret }
}
```

- `parent: keyVault` → "This secret lives inside that vault."
- `name: 'app-secret'` → the secret's identifier. Referenced from the Function App's `APP_SECRET` setting as `@Microsoft.KeyVault(VaultName=...;SecretName=app-secret)`.
- `properties.value: appSecret` → the actual secret content. Comes from a `@secure()` Bicep parameter, so it never appears in deployment logs or template exports.

### Where does `appSecret` come from?

In `main.bicep`:

```bicep
@secure()
param appSecret string

module kv 'modules/keyVault.bicep' = {
  params: { ... appSecret: appSecret }
}
```

And `parameters/dev.bicepparam`:

```bicep
param appSecret = 'some-dev-value'
```

Or — for production — you'd pass it on the CLI:

```powershell
az deployment group create ... --parameters appSecret=$env:APP_SECRET
```

The `@secure()` annotation makes Azure treat the value as sensitive: redacted in logs, not returned by `az deployment show`, not visible in the portal "Inputs" tab.

---

## Scene 3 — The outputs (sticky notes)

```bicep
output keyVaultName  string = keyVault.name
output keyVaultUri   string = keyVault.properties.vaultUri    // https://<name>.vault.azure.net/
output appSecretName string = appSecretEntry.name             // 'app-secret'
```

- `keyVaultName` → piped into `kvRoleAssignment.bicep` (so it knows which vault to grant access on) and into `functionApp.bicep`'s `APP_SECRET = @Microsoft.KeyVault(VaultName=...;...)` setting.
- `keyVaultUri` → the data-plane URL. **Opening it in a browser gives 404** — that's expected. It's a REST API endpoint, not a webpage. Use the portal or `az keyvault secret list` to manage contents.
- `appSecretName` → just exposes the literal `'app-secret'` so other modules don't hard-code the string.

---

## Scene 4 — Why RBAC instead of access policies?

Key Vault has *two* permission systems, and they're mutually exclusive per vault:

| System | How permissions are granted | Pros | Cons |
|---|---|---|---|
| **Access policies** (old) | A list inside the vault: "user X can get/list secrets; app Y can wrap/unwrap keys." | Granular per-data-action. | Different mental model from every other Azure service. Hard to audit centrally. |
| **RBAC** (new, `enableRbacAuthorization: true`) | Standard Azure role assignments on the vault scope. | Same as every other resource. Auditable centrally. Works with PIM. | Slightly coarser-grained. |

**Modern best practice = RBAC.** That's why `kvRoleAssignment.bicep` uses a `Microsoft.Authorization/roleAssignments` resource (same pattern as Storage), and why the vault has `enableRbacAuthorization: true`.

---

## Scene 5 — Why soft-delete trips redeploys

When you run `destroy.ps1` followed by `deploy.ps1`, Bicep tries to create a vault with the same name. Azure says:

> "There's already a soft-deleted vault with that name in this region. Either pick a different name, restore it, or purge it first."

`deploy.ps1` solves this in stage 1a:

```powershell
$deleted = & $az keyvault list-deleted -o json | ConvertFrom-Json |
    Where-Object { $_.name -like 'portfolio*' -and $_.properties.location -eq $Location }
foreach ($d in $deleted) {
    & $az keyvault purge --name $d.name --location $Location --no-wait
}
```

This is why the README in the project root documents the deploy script's 1a step so prominently — it's the most common cause of "ConflictError" on redeploy if you ever fork this project.

---

## The 5-Second Mental Model

1. **Key Vault is a managed safety-deposit box.** Renting one = `Microsoft.KeyVault/vaults` with `sku: standard` + `enableRbacAuthorization: true`.
2. **Always RBAC, never access policies** for new vaults — consistent with all other Azure RBAC.
3. **Secrets are child resources** — `Microsoft.KeyVault/vaults/secrets` with `parent: keyVault` and a `@secure()` parameter for the value.
4. **The vault URI is a REST endpoint**, not a webpage. 404 in a browser is expected — use the portal or Azure CLI.
5. **Soft-delete is mandatory** with min 7-day retention. Same-name redeploys need `az keyvault purge` first — that's what `deploy.ps1` stage 1a handles.
6. **Outputs are sticky notes** — `keyVaultName` for the role-assignment module and the Function App's `APP_SECRET` reference string.
