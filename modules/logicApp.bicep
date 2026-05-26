// ============================================================
// logicApp.bicep — The Notifier (Logic App, Consumption tier)
// Triggers when contact form is submitted via Function App
// ============================================================

@description('Azure region')
param location string

@description('Logic App name')
param logicAppName string

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppName
  location: location
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              type: 'object'
              properties: {
                name: { type: 'string' }
                email: { type: 'string' }
                message: { type: 'string' }
              }
              required: [ 'name', 'email', 'message' ]
            }
          }
        }
      }
      actions: {
        Response: {
          type: 'Response'
          kind: 'Http'
          inputs: {
            statusCode: 200
            body: {
              status: 'received'
              message: 'Contact form submitted successfully'
            }
          }
        }
      }
      outputs: {}
    }
  }
}

output logicAppEndpoint string = logicApp.properties.accessEndpoint
output logicAppCallbackUrl string = listCallbackUrl('${logicApp.id}/triggers/manual', '2019-05-01').value
