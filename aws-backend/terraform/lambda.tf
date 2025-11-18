# Lambda Function for Skin Analysis

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${local.prefix}-lambda-role"

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

  tags = local.common_tags
}

# IAM Policy for Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${local.prefix}-lambda-policy"
  role = aws_iam_role.lambda_role.id

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
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.images.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"  # Added for products table scanning
        ]
        Resource = [
          aws_dynamodb_table.analyses.arn,
          "${aws_dynamodb_table.analyses.arn}/index/*",
          aws_dynamodb_table.products.arn,
          "${aws_dynamodb_table.products.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeAgent",
          "bedrock-runtime:InvokeModel"  # For Claude 3.5 Sonnet
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${local.prefix}-personalized-insights-generator"
        ]
      }
    ]
  })
}

# Lambda function
resource "aws_lambda_function" "analyze_skin" {
  filename         = "${path.module}/../lambda/lambda_deployment.zip"
  function_name    = "${local.prefix}-analyze-skin"
  role            = aws_iam_role.lambda_role.arn
  handler         = "handler.lambda_handler"
  source_code_hash = filebase64sha256("${path.module}/../lambda/lambda_deployment.zip")
  runtime         = "python3.11"
  timeout         = 120  # Increased from 60s to 120s for HuggingFace + Bedrock calls
  memory_size     = 1024

  environment {
    variables = {
      ANALYSES_TABLE             = aws_dynamodb_table.analyses.name
      PRODUCTS_TABLE             = aws_dynamodb_table.products.name
      S3_BUCKET                  = aws_s3_bucket.images.id
      HUGGINGFACE_URL            = var.huggingface_api_url
      BEDROCK_AGENT_ID           = ""
    }
  }

  tags = local.common_tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.analyze_skin.function_name}"
  retention_in_days = 14
  tags              = local.common_tags
}

# Lambda permission for S3 to invoke
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.analyze_skin.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.images.arn
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "allow_apigateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.analyze_skin.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# Output
output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.analyze_skin.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.analyze_skin.arn
}

