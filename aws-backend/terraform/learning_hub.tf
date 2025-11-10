# Learning Hub Infrastructure
# AI-powered chatbot with RAG, vector search, and user context

# DynamoDB table for chat history
resource "aws_dynamodb_table" "chat_history" {
  name           = "${var.project_name}-${var.environment}-chat-history"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "user_id"
  range_key      = "timestamp"

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

  tags = {
    Name        = "${var.project_name}-${var.environment}-chat-history"
    Environment = var.environment
  }
}

# DynamoDB table for educational content metadata
resource "aws_dynamodb_table" "educational_content" {
  name           = "${var.project_name}-${var.environment}-educational-content"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "content_id"

  attribute {
    name = "content_id"
    type = "S"
  }

  attribute {
    name = "category"
    type = "S"
  }

  attribute {
    name = "relevance_score"
    type = "N"
  }

  global_secondary_index {
    name            = "CategoryIndex"
    hash_key        = "category"
    range_key       = "relevance_score"
    projection_type = "ALL"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-educational-content"
    Environment = var.environment
  }
}

# Lambda function for Learning Hub chatbot
resource "aws_lambda_function" "learning_hub_chatbot" {
  filename         = "${path.module}/../lambda/learning_hub.zip"
  function_name    = "${var.project_name}-${var.environment}-learning-hub-chatbot"
  role            = aws_iam_role.learning_hub_lambda_role.arn
  handler         = "learning_hub_handler.lambda_handler"
  source_code_hash = fileexists("${path.module}/../lambda/learning_hub.zip") ? filebase64sha256("${path.module}/../lambda/learning_hub.zip") : ""
  runtime         = "python3.11"
  timeout         = 120
  memory_size     = 1024

  environment {
    variables = {
      CHAT_HISTORY_TABLE       = aws_dynamodb_table.chat_history.name
      EDUCATIONAL_CONTENT_TABLE = aws_dynamodb_table.educational_content.name
      ANALYSES_TABLE           = var.analyses_table_name
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-learning-hub-chatbot"
    Environment = var.environment
  }
}

# IAM role for Learning Hub Lambda
resource "aws_iam_role" "learning_hub_lambda_role" {
  name = "${var.project_name}-${var.environment}-learning-hub-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-learning-hub-lambda-role"
    Environment = var.environment
  }
}

# IAM policy for Learning Hub Lambda
resource "aws_iam_role_policy" "learning_hub_lambda_policy" {
  name = "${var.project_name}-${var.environment}-learning-hub-lambda-policy"
  role = aws_iam_role.learning_hub_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          aws_dynamodb_table.chat_history.arn,
          "${aws_dynamodb_table.chat_history.arn}/index/*",
          aws_dynamodb_table.educational_content.arn,
          "${aws_dynamodb_table.educational_content.arn}/index/*",
          "arn:aws:dynamodb:${var.aws_region}:*:table/${var.analyses_table_name}",
          "arn:aws:dynamodb:${var.aws_region}:*:table/${var.analyses_table_name}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "learning_hub_logs" {
  name              = "/aws/lambda/${aws_lambda_function.learning_hub_chatbot.function_name}"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-${var.environment}-learning-hub-logs"
    Environment = var.environment
  }
}

# Variables
variable "analyses_table_name" {
  description = "Name of the analyses DynamoDB table"
  type        = string
  default     = ""
}

# Outputs
output "learning_hub_lambda_arn" {
  value       = aws_lambda_function.learning_hub_chatbot.arn
  description = "ARN of the Learning Hub Lambda function"
}

output "chat_history_table_name" {
  value       = aws_dynamodb_table.chat_history.name
  description = "Name of the chat history DynamoDB table"
}

output "educational_content_table_name" {
  value       = aws_dynamodb_table.educational_content.name
  description = "Name of the educational content DynamoDB table"
}

