param environmentName string
param location string = resourceGroup().location
param resourceSuffix string = 'a1'
param cosmosDatabaseName string = 'review-memory-agent'
param functionInstanceMemoryMB int = 512
param functionAlwaysReadyInstances int = 0
param staticWebAppSku string = 'Free'
param documentIntelligenceSku string = 'S0'
param foundryMainDeploymentName string = 'claude-main'
param foundryFastDeploymentName string = 'claude-fast'
param foundryReasoningDeploymentName string = 'claude-reasoning'
param openAiEmbeddingDeploymentName string = 'text-embedding-main'
param enableMonitoring bool = false
param enableCosmos bool = false
param enableDocumentIntelligence bool = false
param enableFoundry bool = false
param enableOpenAI bool = false
param enableKeyVault bool = false
param linkFunctionToStaticWebApp bool = false

var tags = {
  application: 'review-memory-agent'
  environment: environmentName
  managedBy: 'azd'
}

var storageAccountName = toLower('strma${environmentName}${resourceSuffix}')
var functionAppName = 'func-rma-${environmentName}-${resourceSuffix}'
var staticWebAppName = 'stapp-rma-${environmentName}-${resourceSuffix}'
var cosmosAccountName = 'cosmos-rma-${environmentName}-${resourceSuffix}'
var docIntelName = 'docint-rma-${environmentName}-${resourceSuffix}'
var foundryName = 'aif-rma-${environmentName}-${resourceSuffix}'
var openAiName = 'aoai-rma-${environmentName}-${resourceSuffix}'
var keyVaultName = 'kv-rma-${environmentName}-${resourceSuffix}'
var appInsightsName = 'appi-rma-${environmentName}-${resourceSuffix}'
var logAnalyticsName = 'log-rma-${environmentName}-${resourceSuffix}'
var functionPlanName = 'plan-rma-${environmentName}-${resourceSuffix}'

module monitoring 'modules/monitoring.bicep' = if (enableMonitoring) {
  name: 'monitoring'
  params: {
    location: location
    applicationInsightsName: appInsightsName
    workspaceName: logAnalyticsName
    tags: tags
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    location: location
    storageAccountName: storageAccountName
    tags: tags
  }
}

module cosmos 'modules/cosmos.bicep' = if (enableCosmos) {
  name: 'cosmos'
  params: {
    accountName: cosmosAccountName
    databaseName: cosmosDatabaseName
    location: location
    tags: tags
  }
}

module docintelligence 'modules/docintelligence.bicep' = if (enableDocumentIntelligence) {
  name: 'docintelligence'
  params: {
    accountName: docIntelName
    location: location
    skuName: documentIntelligenceSku
    tags: tags
  }
}

module foundry 'modules/foundry.bicep' = if (enableFoundry) {
  name: 'foundry'
  params: {
    accountName: foundryName
    location: location
    tags: tags
  }
}

module openai 'modules/openai.bicep' = if (enableOpenAI) {
  name: 'openai'
  params: {
    accountName: openAiName
    location: location
    tags: tags
  }
}

module keyvault 'modules/keyvault.bicep' = if (enableKeyVault) {
  name: 'keyvault'
  params: {
    location: location
    tenantId: subscription().tenantId
    vaultName: keyVaultName
    storageConnectionString: storage.outputs.connectionString
    cosmosKey: enableCosmos ? cosmos.outputs.primaryKey : ''
    docIntelligenceKey: enableDocumentIntelligence ? docintelligence.outputs.primaryKey : ''
    foundryApiKey: enableFoundry ? foundry.outputs.primaryKey : ''
    openAiApiKey: enableOpenAI ? openai.outputs.primaryKey : ''
    applicationInsightsConnectionString: enableMonitoring ? monitoring.outputs.connectionString : ''
    tags: tags
  }
}

module functions 'modules/functions.bicep' = {
  name: 'functions'
  params: {
    appInsightsConnectionString: enableMonitoring ? monitoring.outputs.connectionString : ''
    appName: functionAppName
    environmentName: environmentName
    cosmosDatabaseName: cosmosDatabaseName
    cosmosEndpoint: enableCosmos ? cosmos.outputs.endpoint : ''
    cosmosKey: enableCosmos ? cosmos.outputs.primaryKey : ''
    deploymentStorageConnectionString: storage.outputs.connectionString
    docIntelligenceEndpoint: enableDocumentIntelligence ? docintelligence.outputs.endpoint : ''
    docIntelligenceKey: enableDocumentIntelligence ? docintelligence.outputs.primaryKey : ''
    foundryApiKey: enableFoundry ? foundry.outputs.primaryKey : ''
    foundryEndpoint: enableFoundry ? foundry.outputs.endpoint : ''
    foundryFastDeploymentName: foundryFastDeploymentName
    foundryMainDeploymentName: foundryMainDeploymentName
    foundryReasoningDeploymentName: foundryReasoningDeploymentName
    keyVaultName: enableKeyVault ? keyvault.outputs.name : ''
    location: location
    openAiApiKey: enableOpenAI ? openai.outputs.primaryKey : ''
    openAiEmbeddingDeploymentName: openAiEmbeddingDeploymentName
    openAiEndpoint: enableOpenAI ? openai.outputs.endpoint : ''
    planName: functionPlanName
    storageAccountName: storage.outputs.name
    storageBlobEndpoint: storage.outputs.blobEndpoint
    storageConnectionString: storage.outputs.connectionString
    storageQueueEndpoint: storage.outputs.queueEndpoint
    storageContainers: storage.outputs.containerNames
    storageQueues: storage.outputs.queueNames
    tags: tags
    alwaysReadyInstances: functionAlwaysReadyInstances
    instanceMemoryMB: functionInstanceMemoryMB
    enableMonitoring: enableMonitoring
    enableCosmos: enableCosmos
    enableDocumentIntelligence: enableDocumentIntelligence
    enableFoundry: enableFoundry
    enableOpenAI: enableOpenAI
    enableKeyVault: enableKeyVault
  }
}

module staticwebapp 'modules/staticwebapp.bicep' = {
  name: 'staticwebapp'
  params: {
    functionAppResourceId: functions.outputs.resourceId
    location: location
    name: staticWebAppName
    sku: staticWebAppSku
    tags: tags
    linkBackend: linkFunctionToStaticWebApp
  }
}

output azureFunctionsName string = functions.outputs.name
output azureFunctionsUrl string = functions.outputs.defaultHostname
output staticWebAppName string = staticwebapp.outputs.name
output staticWebAppUrl string = staticwebapp.outputs.defaultHostname
output storageAccountName string = storage.outputs.name
output cosmosAccountName string = enableCosmos ? cosmos.outputs.name : ''
output keyVaultName string = enableKeyVault ? keyvault.outputs.name : ''
