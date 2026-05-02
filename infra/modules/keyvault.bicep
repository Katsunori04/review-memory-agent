param location string
param tenantId string
param vaultName string
@secure()
param storageConnectionString string
@secure()
param cosmosKey string
@secure()
param docIntelligenceKey string
@secure()
param foundryApiKey string
@secure()
param openAiApiKey string
@secure()
param applicationInsightsConnectionString string
param tags object = {}

resource vault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: vaultName
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    enableRbacAuthorization: true
    enabledForTemplateDeployment: true
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: []
    publicNetworkAccess: 'Enabled'
  }
}

resource storageSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vault
  name: 'AZURE-STORAGE-CONNECTION-STRING'
  properties: {
    value: storageConnectionString
  }
}

resource cosmosSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vault
  name: 'COSMOS-KEY'
  properties: {
    value: cosmosKey
  }
}

resource docIntSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vault
  name: 'DOCINT-KEY'
  properties: {
    value: docIntelligenceKey
  }
}

resource foundrySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vault
  name: 'FOUNDRY-API-KEY'
  properties: {
    value: foundryApiKey
  }
}

resource openAiSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vault
  name: 'AZURE-OPENAI-API-KEY'
  properties: {
    value: openAiApiKey
  }
}

resource appInsightsSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vault
  name: 'APPLICATIONINSIGHTS-CONNECTION-STRING'
  properties: {
    value: applicationInsightsConnectionString
  }
}

output name string = vault.name
output id string = vault.id
output uri string = vault.properties.vaultUri
