# DynamoDB Tables

# Table 1: Skin Analyses (stores analysis results)
resource "aws_dynamodb_table" "analyses" {
  name           = "${local.prefix}-analyses"
  billing_mode   = "PAY_PER_REQUEST" # On-demand pricing
  hash_key       = "analysis_id"
  range_key      = "user_id"

  attribute {
    name = "analysis_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  # Global Secondary Index for querying by user
  global_secondary_index {
    name            = "UserIndex"
    hash_key        = "user_id"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  # TTL for automatic cleanup after 90 days
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  # Server-side encryption
  server_side_encryption {
    enabled = true
  }

  tags = local.common_tags
}

# Table 2: Products (skincare products database)
resource "aws_dynamodb_table" "products" {
  name         = "${local.prefix}-products"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "product_id"

  attribute {
    name = "product_id"
    type = "S"
  }

  attribute {
    name = "category"
    type = "S"
  }

  attribute {
    name = "rating"
    type = "N"
  }

  # GSI for querying by category
  global_secondary_index {
    name            = "CategoryIndex"
    hash_key        = "category"
    range_key       = "rating"
    projection_type = "ALL"
  }

  server_side_encryption {
    enabled = true
  }

  tags = local.common_tags
}

# Outputs
output "dynamodb_analyses_table" {
  description = "Name of analyses DynamoDB table"
  value       = aws_dynamodb_table.analyses.name
}

output "dynamodb_products_table" {
  description = "Name of products DynamoDB table"
  value       = aws_dynamodb_table.products.name
}

