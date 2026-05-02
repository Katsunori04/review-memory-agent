param location string
param storageAccountName string
param tags object = {}

var blobContainers = [
  'documents-original'
  'documents-extracted'
  'reviews-results'
  'vision-pages'
  'deployment-package'
]

var queues = [
  'document-analysis'
  'review-jobs'
]

resource storage 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  tags: tags
  properties: {
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' = {
  parent: storage
  name: 'default'
}

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2024-01-01' = {
  parent: storage
  name: 'default'
}

resource blobContainersResource 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = [for containerName in blobContainers: {
  parent: blobService
  name: containerName
  properties: {
    publicAccess: 'None'
  }
}]

resource queueResources 'Microsoft.Storage/storageAccounts/queueServices/queues@2024-01-01' = [for queueName in queues: {
  parent: queueService
  name: queueName
}]

var storageKeys = listKeys(storage.id, '2024-01-01')
var connectionString = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${storageKeys.keys[0].value};EndpointSuffix=${environment().suffixes.storage}'

output name string = storage.name
output id string = storage.id
output blobEndpoint string = storage.properties.primaryEndpoints.blob
output queueEndpoint string = storage.properties.primaryEndpoints.queue
@secure()
output connectionString string = connectionString
output containerNames object = {
  documentsOriginal: blobContainers[0]
  documentsExtracted: blobContainers[1]
  reviewsResults: blobContainers[2]
  visionPages: blobContainers[3]
  deploymentPackage: blobContainers[4]
}
output queueNames object = {
  documentAnalysis: queues[0]
  reviewJobs: queues[1]
}
