# `storageRoleAssignment.bicep` — The Story of Three More Cupboards

> Same student, three more locked doors

You've read `kvRoleAssignment.README.md`. Same pattern, repeated three times — one **permission slip per cupboard** the Function App needs to open inside the storage account.

A storage account isn't *one* cupboard; it's **three** sub-services that each have their own RBAC roles:

| Sub-service | Built-in role used here | GUID | Why the Function App needs it |
|---|---|---|---|
| **Blob** | Storage Blob Data Owner | `b7e6dc6d-f1e8-4753-8033-0f276bb0955b` | Read/write the **deployment-package container** (Flex Consumption pulls the app zip from here) and the `$web` container at deploy time. |
| **Queue** | Storage Queue Data Contributor | `974c5e8b-45b9-4653-ba55-5f855dd0fb88` | The Functions host uses internal queues for distributed locks / triggers (part of `AzureWebJobsStorage`). |
| **Table** | Storage Table Data Contributor | `0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3` | Your code reads `profiles` and writes `contacts`. The Functions host also uses tables for system state. |

---

## The shape of one assignment

Each block is the same three-blank form from the KV story:

```bicep
resource blobOwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount                                          // ← WHERE
  name:  guid(storageAccount.id, principalId, roleIds.blobDataOwner)
  properties: {
    principalId:      principalId                                // ← WHO
    principalType:    'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(                    // ← WHAT
                        'Microsoft.Authorization/roleDefinitions',
                        roleIds.blobDataOwner)
  }
}
```

Repeated for `queueContributor` and `tableContributor`. Three resources, three permission slips, all pinned at the storage-account scope. Each `guid(...)` uses a different role GUID so they don't collide.

---

## Why "Data" roles and not "Contributor"?

There are two layers of permissions in Azure storage:

| Layer | Role family | What it controls |
|---|---|---|
| **Control plane** (ARM) | `Storage Account Contributor` | Create/delete the account, regenerate keys, change firewall rules. |
| **Data plane** (REST) | `Storage Blob/Queue/Table Data ...` | Actually read/write the **contents** (blobs, queue messages, table rows). |

You only need the **data-plane** roles for the Function App, because it doesn't create or destroy storage accounts — it just reads/writes the contents. Giving control-plane permissions would be over-privileged (violates least-privilege).

---

## Why `Owner` for Blob but `Contributor` for Queue/Table?

- **Blob Data Owner** includes the right to manage POSIX-style ACLs and override container-level settings. Flex Consumption's deployment storage block sometimes needs this to manage the package container metadata.
- **Queue/Table Data Contributor** is enough for read/write data — no ownership needed.

(If you wanted to be even stricter, you could downgrade Blob to `Storage Blob Data Contributor`. Microsoft's official Flex Consumption sample uses Owner, so we match that.)

---

## How `main.bicep` wires it up

```bicep
module storageRoles 'modules/storageRoleAssignment.bicep' = {
  name: 'storageRoleAssignment'
  params: {
    storageAccountName: storage.outputs.storageAccountName
    principalId:        func.outputs.functionAppPrincipalId
  }
}
```

Same `principalId` as `kvRoleAssignment` — the same Function App MI gets badges for both Key Vault AND Storage.

---

## The 5-Second Mental Model

1. **A storage account = three data planes** (Blob, Queue, Table). Each has its own RBAC role.
2. **Three identical role-assignment blocks** at storage-account scope, one per role. Same `principalId`, different `roleDefinitionId`, different `guid(...)` so they don't collide.
3. **Data-plane roles only** — Function App reads/writes contents, doesn't manage the account.
4. **Once these three slips are signed**, the Function App can: fetch its own app package (Blob), drive internal Functions runtime state (Queue + Table), and read/write your `profiles` + `contacts` tables (Table) — **all without a single connection string in source.**

Same pattern as `kvRoleAssignment`, just multiplied by three. One badge, four cupboards opened.
