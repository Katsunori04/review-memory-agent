param functionAppResourceId string
param location string
param name string
param sku string = 'Standard'
param tags object = {}
param linkBackend bool = false

resource staticWebApp 'Microsoft.Web/staticSites@2024-04-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
    tier: sku
  }
  properties: {}
}

resource linkedBackend 'Microsoft.Web/staticSites/linkedBackends@2024-04-01' = if (linkBackend) {
  parent: staticWebApp
  name: 'linkedBackend'
  properties: {
    backendResourceId: functionAppResourceId
    region: location
  }
}

output name string = staticWebApp.name
output id string = staticWebApp.id
output defaultHostname string = 'https://${staticWebApp.properties.defaultHostname}'
