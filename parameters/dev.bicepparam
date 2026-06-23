using '../main.bicep'

param location = 'centralindia'
param projectName = 'portfolio'
param appSecret = 'REPLACE_AT_DEPLOY_TIME' // Pass via: --parameters appSecret=<value>
param enableEntraAuth = false
param entraTenantId = ''
param entraApiClientId = ''
// When enableEntraAuth is true, allowed audiences are derived from entraApiClientId.
