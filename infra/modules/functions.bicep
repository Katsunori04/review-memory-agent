param appInsightsConnectionString string
param appName string
param environmentName string
param cosmosDatabaseName string
param cosmosEndpoint string
@secure()
param cosmosKey string
@secure()
param deploymentStorageConnectionString string
param docIntelligenceEndpoint string
@secure()
param docIntelligenceKey string
@secure()
param foundryApiKey string
param foundryEndpoint string
param foundryFastDeploymentName string
param foundryMainDeploymentName string
param foundryReasoningDeploymentName string
param keyVaultName string
param location string
@secure()
param openAiApiKey string
param openAiEmbeddingDeploymentName string
param openAiEndpoint string
param planName string
param storageAccountName string
param storageBlobEndpoint string
@secure()
param storageConnectionString string
param storageQueueEndpoint string
param storageContainers object
param storageQueues object
param tags object = {}
param alwaysReadyInstances int = 0
param instanceMemoryMB int = 2048
param enableMonitoring bool = false
param enableCosmos bool = false
param enableDocumentIntelligence bool = false
param enableFoundry bool = false
param enableOpenAI bool = false
param enableKeyVault bool = false

resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: planName
  location: location
  kind: 'functionapp'
  sku: {
    tier: 'FlexConsumption'
    name: 'FC1'
  }
  tags: tags
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: appName
  location: location
  kind: 'functionapp,linux'
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storageBlobEndpoint}${storageContainers.deploymentPackage}'
          authentication: {
            type: 'StorageAccountConnectionString'
            storageAccountConnectionStringName: 'DEPLOYMENT_STORAGE_CONNECTION_STRING'
          }
        }
      }
      runtime: {
        name: 'python'
        version: '3.12'
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 100
        instanceMemoryMB: instanceMemoryMB
        alwaysReady: alwaysReadyInstances < 1 ? [] : [
          {
            name: 'http'
            instanceCount: alwaysReadyInstances
          }
        ]
      }
    }
    siteConfig: {
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: storageConnectionString
        }
        {
          name: 'DEPLOYMENT_STORAGE_CONNECTION_STRING'
          value: deploymentStorageConnectionString
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: enableMonitoring ? appInsightsConnectionString : ''
        }
        {
          name: 'AZURE_ENV_NAME'
          value: environmentName
        }
        {
          name: 'STORAGE_ACCOUNT_NAME'
          value: storageAccountName
        }
        {
          name: 'STORAGE_BLOB_ENDPOINT'
          value: storageBlobEndpoint
        }
        {
          name: 'STORAGE_QUEUE_ENDPOINT'
          value: storageQueueEndpoint
        }
        {
          name: 'BLOB_CONTAINER_DOCUMENTS_ORIGINAL'
          value: storageContainers.documentsOriginal
        }
        {
          name: 'BLOB_CONTAINER_DOCUMENTS_EXTRACTED'
          value: storageContainers.documentsExtracted
        }
        {
          name: 'BLOB_CONTAINER_REVIEWS_RESULTS'
          value: storageContainers.reviewsResults
        }
        {
          name: 'BLOB_CONTAINER_VISION_PAGES'
          value: storageContainers.visionPages
        }
        {
          name: 'QUEUE_DOCUMENT_ANALYSIS'
          value: storageQueues.documentAnalysis
        }
        {
          name: 'QUEUE_REVIEW_JOBS'
          value: storageQueues.reviewJobs
        }
        {
          name: 'COSMOS_ENDPOINT'
          value: enableCosmos ? cosmosEndpoint : ''
        }
        {
          name: 'COSMOS_DATABASE_NAME'
          value: enableCosmos ? cosmosDatabaseName : ''
        }
        {
          name: 'COSMOS_KEY'
          value: enableCosmos ? cosmosKey : ''
        }
        {
          name: 'COSMOS_CONTAINER_DOCUMENTS'
          value: 'documents'
        }
        {
          name: 'COSMOS_CONTAINER_REVIEW_SETS'
          value: 'review_sets'
        }
        {
          name: 'COSMOS_CONTAINER_REVIEW_JOBS'
          value: 'review_jobs'
        }
        {
          name: 'COSMOS_CONTAINER_REVIEWS'
          value: 'reviews'
        }
        {
          name: 'COSMOS_CONTAINER_REVIEW_FEEDBACK'
          value: 'review_feedback'
        }
        {
          name: 'COSMOS_CONTAINER_MEMORY_SOURCES'
          value: 'memory_sources'
        }
        {
          name: 'COSMOS_CONTAINER_MEMORY_CANDIDATES'
          value: 'memory_candidates'
        }
        {
          name: 'COSMOS_CONTAINER_MEMORY_CARD_DRAFTS'
          value: 'memory_card_drafts'
        }
        {
          name: 'COSMOS_CONTAINER_MEMORY_CARDS'
          value: 'memory_cards'
        }
        {
          name: 'DOCINT_ENDPOINT'
          value: enableDocumentIntelligence ? docIntelligenceEndpoint : ''
        }
        {
          name: 'DOCINT_KEY'
          value: enableDocumentIntelligence ? docIntelligenceKey : ''
        }
        {
          name: 'DOCINT_MODEL_LAYOUT'
          value: 'prebuilt-layout'
        }
        {
          name: 'DOCINT_ENABLE_FIGURES'
          value: enableDocumentIntelligence ? 'true' : 'false'
        }
        {
          name: 'FOUNDRY_ENDPOINT'
          value: enableFoundry ? foundryEndpoint : ''
        }
        {
          name: 'FOUNDRY_API_KEY'
          value: enableFoundry ? foundryApiKey : ''
        }
        {
          name: 'FOUNDRY_CLAUDE_MAIN_DEPLOYMENT'
          value: foundryMainDeploymentName
        }
        {
          name: 'FOUNDRY_CLAUDE_FAST_DEPLOYMENT'
          value: foundryFastDeploymentName
        }
        {
          name: 'FOUNDRY_CLAUDE_REASONING_DEPLOYMENT'
          value: foundryReasoningDeploymentName
        }
        {
          name: 'AZURE_OPENAI_ENDPOINT'
          value: enableOpenAI ? openAiEndpoint : ''
        }
        {
          name: 'AZURE_OPENAI_API_KEY'
          value: enableOpenAI ? openAiApiKey : ''
        }
        {
          name: 'AZURE_OPENAI_EMBEDDING_DEPLOYMENT'
          value: openAiEmbeddingDeploymentName
        }
        {
          name: 'FEATURE_ENABLE_MULTIMODAL_DIAGRAM'
          value: enableDocumentIntelligence ? 'true' : 'false'
        }
        {
          name: 'FEATURE_ENABLE_REVIEW_RERUN'
          value: 'true'
        }
        {
          name: 'FEATURE_ENABLE_MEMORY_SEARCH'
          value: enableCosmos && enableOpenAI ? 'true' : 'false'
        }
        {
          name: 'KEY_VAULT_NAME'
          value: enableKeyVault ? keyVaultName : ''
        }
      ]
    }
  }
}

output name string = functionApp.name
output resourceId string = functionApp.id
output defaultHostname string = 'https://${functionApp.properties.defaultHostName}'
