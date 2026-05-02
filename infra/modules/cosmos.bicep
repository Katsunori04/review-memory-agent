param accountName string
param databaseName string
param location string
param tags object = {}

var standardContainers = [
  {
    name: 'documents'
    partitionKey: '/reviewSetId'
  }
  {
    name: 'review_sets'
    partitionKey: '/id'
  }
  {
    name: 'review_jobs'
    partitionKey: '/reviewSetId'
  }
  {
    name: 'reviews'
    partitionKey: '/reviewSetId'
  }
  {
    name: 'review_feedback'
    partitionKey: '/reviewSetId'
  }
  {
    name: 'memory_sources'
    partitionKey: '/id'
  }
  {
    name: 'memory_candidates'
    partitionKey: '/memorySourceId'
  }
  {
    name: 'memory_card_drafts'
    partitionKey: '/memorySourceId'
  }
]

resource account 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: accountName
  location: location
  kind: 'GlobalDocumentDB'
  tags: tags
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        failoverPriority: 0
        isZoneRedundant: false
        locationName: location
      }
    ]
    capabilities: [
      {
        name: 'EnableNoSQLVectorSearch'
      }
    ]
    publicNetworkAccess: 'Enabled'
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    disableLocalAuth: false
    minimalTlsVersion: 'Tls12'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
  }
}

resource sqlDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-11-15' = {
  parent: account
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
    options: {}
  }
}

resource containers 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2025-04-15' = [
  for container in standardContainers: {
    parent: sqlDatabase
    name: container.name
    properties: {
      resource: {
        id: container.name
        partitionKey: {
          kind: 'Hash'
          paths: [
            container.partitionKey
          ]
        }
        indexingPolicy: {
          indexingMode: 'consistent'
          automatic: true
          includedPaths: [
            {
              path: '/*'
            }
          ]
          excludedPaths: [
            {
              path: '/"_etag"/?'
            }
          ]
        }
      }
      options: {}
    }
  }
]

resource memoryCards 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2025-04-15' = {
  parent: sqlDatabase
  name: 'memory_cards'
  properties: {
    resource: {
      id: 'memory_cards'
      partitionKey: {
        kind: 'Hash'
        paths: [
          '/id'
        ]
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
        vectorIndexes: [
          {
            path: '/embedding'
            type: 'quantizedFlat'
          }
        ]
      }
      vectorEmbeddingPolicy: {
        vectorEmbeddings: [
          {
            path: '/embedding'
            dataType: 'float32'
            distanceFunction: 'cosine'
            dimensions: 1536
          }
        ]
      }
    }
    options: {}
  }
}

var keys = listKeys(account.id, '2024-11-15')

output name string = account.name
output id string = account.id
output endpoint string = account.properties.documentEndpoint
@secure()
output primaryKey string = keys.primaryMasterKey
