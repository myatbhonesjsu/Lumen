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
