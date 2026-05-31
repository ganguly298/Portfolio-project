// ============================================================
// storageRoleAssignment.bicep
// Grants the Function App's managed identity the data-plane roles
// it needs on the storage account:
//  - Storage Blob Data Owner       (AzureWebJobsStorage + deployment container)
//  - Storage Queue Data Contributor(AzureWebJobsStorage queues)
//  - Storage Table Data Contributor(profiles & contacts tables + AzureWebJobsStorage tables)
// ============================================================

@description('Storage account name')
param storageAccountName string

@description('Principal ID of the Function App managed identity')
param principalId string

var roleIds = {
  blobDataOwner:       'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  queueDataContributor:'974c5e8b-45b9-4653-ba55-5f855dd0fb88'
  tableDataContributor:'0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-04-01' existing = {
  name: storageAccountName
}

resource blobOwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, principalId, roleIds.blobDataOwner)
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.blobDataOwner)
  }
}

resource queueContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, principalId, roleIds.queueDataContributor)
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.queueDataContributor)
  }
}

resource tableContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, principalId, roleIds.tableDataContributor)
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.tableDataContributor)
  }
}
