# Pinecone Vector Database Configuration
# Stores embeddings for RAG (Retrieval-Augmented Generation)

# Store Pinecone API key in AWS Secrets Manager
resource "aws_secretsmanager_secret" "pinecone_api_key" {
  name        = "${local.prefix}-pinecone-api-key"
  description = "Pinecone API key for vector database access"
  tags        = local.common_tags
}

# Placeholder for Pinecone API key value (set manually or via CLI)
# aws secretsmanager put-secret-value \
#   --secret-id lumen-skincare-dev-pinecone-api-key \
#   --secret-string "your-pinecone-api-key"

# Pinecone Configuration
# Note: Pinecone index must be created via Pinecone Console or API
# Index name: lumen-skincare-knowledge
# Dimensions: 1536 (AWS Bedrock Titan Embeddings)
# Metric: cosine
# Namespaces:
#   - knowledge-base: Articles, research, ingredients
#   - user-patterns: Historical user behavior
#   - products: Product descriptions & reviews
#   - recommendations: Successful routine patterns

# DynamoDB table for daily insights
resource "aws_dynamodb_table" "daily_insights" {
  name         = "${local.prefix}-daily-insights"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "insight_date"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "insight_date"
    type = "S" # Format: YYYY-MM-DD
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = merge(local.common_tags, {
    Purpose = "Store generated daily insights"
  })
}

# DynamoDB table for check-in responses
resource "aws_dynamodb_table" "checkin_responses" {
  name         = "${local.prefix}-checkin-responses"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "timestamp"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S" # ISO 8601 format
  }

  tags = merge(local.common_tags, {
    Purpose = "Store user check-in responses for pattern analysis"
  })
}

# DynamoDB table for product application tracking
resource "aws_dynamodb_table" "product_applications" {
  name         = "${local.prefix}-product-applications"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "application_id"

  attribute {
    name = "application_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "applied_date"
    type = "S"
  }

  global_secondary_index {
    name            = "UserDateIndex"
    hash_key        = "user_id"
    range_key       = "applied_date"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = merge(local.common_tags, {
    Purpose = "Track when users apply recommended products"
  })
}

# DynamoDB table for chat history (Learning Hub)
resource "aws_dynamodb_table" "chat_history" {
  name         = "${local.prefix}-chat-history"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "timestamp"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  attribute {
    name = "session_id"
    type = "S"
  }

  global_secondary_index {
    name            = "SessionIndex"
    hash_key        = "session_id"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = merge(local.common_tags, {
    Purpose = "Store Learning Hub chat history"
  })
}

# DynamoDB table for educational content (Learning Hub)
resource "aws_dynamodb_table" "educational_content" {
  name         = "${local.prefix}-educational-content"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "content_id"

  attribute {
    name = "content_id"
    type = "S"
  }

  attribute {
    name = "category"
    type = "S"
  }

  global_secondary_index {
    name            = "CategoryIndex"
    hash_key        = "category"
    projection_type = "ALL"
  }

  tags = merge(local.common_tags, {
    Purpose = "Store educational articles and content"
  })
}

# Outputs
output "pinecone_secret_arn" {
  description = "ARN of Pinecone API key secret"
  value       = aws_secretsmanager_secret.pinecone_api_key.arn
}

output "daily_insights_table" {
  description = "Daily insights DynamoDB table name"
  value       = aws_dynamodb_table.daily_insights.name
}

output "checkin_responses_table" {
  description = "Check-in responses DynamoDB table name"
  value       = aws_dynamodb_table.checkin_responses.name
}

output "product_applications_table" {
  description = "Product applications DynamoDB table name"
  value       = aws_dynamodb_table.product_applications.name
}

output "chat_history_table" {
  description = "Chat history DynamoDB table name"
  value       = aws_dynamodb_table.chat_history.name
}

output "educational_content_table" {
  description = "Educational content DynamoDB table name"
  value       = aws_dynamodb_table.educational_content.name
}
