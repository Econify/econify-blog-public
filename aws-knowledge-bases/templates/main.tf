variable "knowledge_base_name" {
  type        = string
  default     = "my-bedrock-kb-demo"
}

variable "source_bucket_name" {
  type        = string
  default     = "my-bedrock-kb-demo-bucket"
}

variable "collection_name" {
  type        = string
  default     = "my-bedrock-kb-demo-collection"
}

variable "index_name" {
  type        = string
  default     = "my-bedrock-kb-demo-collection-index"
}

variable "your_iam_user_arn" {
  type        = string
  description = "This is needed so that you can create the collection index yourself"
}

#########################################
# S3 Bucket for Knowledge Base Documents
#########################################
resource "aws_s3_bucket" "kb_bucket" {
  bucket = var.source_bucket_name
}

#########################################
# OpenSearch Serverless Collection
#########################################
resource "aws_opensearchserverless_security_policy" "encryption" {
  name        = "kb-enc-policy"
  type        = "encryption"
  description = "Encryption policy for KB collection"

  policy = jsonencode({
    Rules = [
      {
        ResourceType = "collection",
        Resource     = ["collection/${var.collection_name}"]
      }
    ],
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "network" {
  name        = "kb-network-policy"
  type        = "network"
  description = "Network policy for KB collection"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType    = "collection"
          Resource        = ["collection/${var.collection_name}"]
        }
      ]
      AllowFromPublic = true
    }
  ])
}

resource "aws_opensearchserverless_collection" "kb_collection" {
  name        = var.collection_name
  type        = "VECTORSEARCH"
  description = "Collection for Bedrock KB vector store"

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network
  ]
}

resource "aws_opensearchserverless_access_policy" "kb_policy" {
  name        = "kb-collection-policy"
  type        = "data"
  description = "Access policy for KB vector store"

  policy = jsonencode([
    {
      Description = "Allow Bedrock KB access",
      Principal = [
        aws_iam_role.bedrock_kb_role.arn,
        var.your_iam_user_arn
      ],
      Rules = [
        {
          ResourceType = "collection",
          Resource     = ["collection/${var.collection_name}"],
          Permission   = ["aoss:*"]
        },
        {
          ResourceType = "index",
          Resource     = ["index/${var.collection_name}/*"],
          Permission   = ["aoss:*"]
        }
      ]
    }
  ])
}

#########################################
# Bedrock Knowledge Base
#########################################
resource "aws_bedrockagent_knowledge_base" "kb" {
  name     = var.knowledge_base_name
  role_arn = aws_iam_role.bedrock_kb_role.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v1"
    }
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn   = aws_opensearchserverless_collection.kb_collection.arn
      vector_index_name = var.index_name
      field_mapping {
        vector_field = "bedrock-vector"
        text_field   = "bedrock-text"
        metadata_field = "bedrock-metadata"
      }
    }
  }
}

#########################################
# Knowledge Base Data Source (S3)
#########################################
resource "aws_bedrockagent_data_source" "kb_s3" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.kb.id
  name              = "kb-s3-source"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = aws_s3_bucket.kb_bucket.arn
    }
  }
}

#########################################
# IAM Role for Bedrock KB
#########################################
resource "aws_iam_role" "bedrock_kb_role" {
  name = "bedrock-kb-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "bedrock_kb_policy" {
  role = aws_iam_role.bedrock_kb_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.kb_bucket.arn,
          "${aws_s3_bucket.kb_bucket.arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = "aoss:APIAccessAll"
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "bedrock:InvokeModel"
        Resource = "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v1"
      }
    ]
  })
}
