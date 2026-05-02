param accountName string
param location string
param tags object = {}

resource account 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: accountName
  location: location
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  tags: tags
  properties: {
    customSubDomainName: accountName
    disableLocalAuth: false
    publicNetworkAccess: 'Enabled'
  }
}

var keys = listKeys(account.id, '2024-10-01')

output name string = account.name
output id string = account.id
output endpoint string = account.properties.endpoint
@secure()
output primaryKey string = keys.key1
