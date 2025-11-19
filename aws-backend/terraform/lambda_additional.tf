# Additional Lambda Functions for Multi-Agent System
# Daily Insights Orchestrator, RAG Query Handler, Vector Embedding Processor

# IAM Role for additional Lambda functions
resource "aws_iam_role" "additional_lambda_role" {
  name = "${local.prefix}-additional-lambda-role"

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

# IAM Policy for additional Lambda functions
resource "aws_iam_role_policy" "additional_lambda_policy" {
  name = "${local.prefix}-additional-lambda-policy"
  role = aws_iam_role.additional_lambda_role.id

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
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.analyses.arn,
          "${aws_dynamodb_table.analyses.arn}/index/*",
          aws_dynamodb_table.daily_insights.arn,
          aws_dynamodb_table.checkin_responses.arn,
          aws_dynamodb_table.product_applications.arn,
          "${aws_dynamodb_table.product_applications.arn}/index/*",
          aws_dynamodb_table.chat_history.arn,
          "${aws_dynamodb_table.chat_history.arn}/index/*",
          aws_dynamodb_table.educational_content.arn,
          "${aws_dynamodb_table.educational_content.arn}/index/*",
          aws_dynamodb_table.products.arn,
          "${aws_dynamodb_table.products.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeAgent",
          "bedrock-runtime:InvokeModel",
          "bedrock-agent-runtime:InvokeAgent"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${local.prefix}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.pinecone_api_key.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = [
          "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${local.prefix}/bedrock/*"
        ]
      }
    ]
  })
}

# Daily Insights Orchestrator Lambda
resource "aws_lambda_function" "daily_insights_orchestrator" {
  filename         = "${path.module}/../lambda/lambda_deployment.zip"
  function_name    = "${local.prefix}-daily-insights-orchestrator"
  role             = aws_iam_role.additional_lambda_role.arn
  handler          = "daily_insights_orchestrator.lambda_handler"
  source_code_hash = filebase64sha256("${path.module}/../lambda/lambda_deployment.zip")
  runtime          = "python3.11"
  timeout          = 300  # 5 minutes for multi-agent workflow
  memory_size     = 1024

  environment {
    variables = {
      ANALYSES_TABLE        = aws_dynamodb_table.analyses.name
      DAILY_INSIGHTS_TABLE  = aws_dynamodb_table.daily_insights.name
      CHECKIN_RESPONSES_TABLE = aws_dynamodb_table.checkin_responses.name
      LAMBDA_PREFIX         = local.prefix
    }
  }

  tags = local.common_tags
}

# RAG Query Handler Lambda
resource "aws_lambda_function" "rag_query_handler" {
  filename         = "${path.module}/../lambda/lambda_deployment.zip"
  function_name    = "${local.prefix}-rag-query-handler"
  role             = aws_iam_role.additional_lambda_role.arn
  handler          = "rag_query_handler.lambda_handler"
  source_code_hash = filebase64sha256("${path.module}/../lambda/lambda_deployment.zip")
  runtime          = "python3.11"
  timeout          = 60
  memory_size      = 512

  environment {
    variables = {
      PINECONE_SECRET_ARN = aws_secretsmanager_secret.pinecone_api_key.arn
      PINECONE_INDEX_NAME = "lumen-skincare-knowledge"
    }
  }

  tags = local.common_tags
}

# Vector Embedding Processor Lambda
resource "aws_lambda_function" "vector_embedding_processor" {
  filename         = "${path.module}/../lambda/lambda_deployment.zip"
  function_name    = "${local.prefix}-vector-embedding-processor"
  role             = aws_iam_role.additional_lambda_role.arn
  handler          = "vector_embedding_processor.lambda_handler"
  source_code_hash = filebase64sha256("${path.module}/../lambda/lambda_deployment.zip")
  runtime          = "python3.11"
  timeout          = 300  # 5 minutes for batch processing
  memory_size      = 1024

  environment {
    variables = {
      PINECONE_SECRET_ARN = aws_secretsmanager_secret.pinecone_api_key.arn
      PINECONE_INDEX_NAME = "lumen-skincare-knowledge"
    }
  }

  tags = local.common_tags
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "daily_insights_orchestrator_logs" {
  name              = "/aws/lambda/${aws_lambda_function.daily_insights_orchestrator.function_name}"
  retention_in_days = 14
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "rag_query_handler_logs" {
  name              = "/aws/lambda/${aws_lambda_function.rag_query_handler.function_name}"
  retention_in_days = 14
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "vector_embedding_processor_logs" {
  name              = "/aws/lambda/${aws_lambda_function.vector_embedding_processor.function_name}"
  retention_in_days = 14
  tags              = local.common_tags
}

# Personalized Insights Generator Lambda
resource "aws_lambda_function" "personalized_insights_generator" {
  filename         = "${path.module}/../lambda/lambda_deployment.zip"
  function_name    = "${local.prefix}-personalized-insights-generator"
  role             = aws_iam_role.additional_lambda_role.arn
  handler          = "personalized_insights_generator.lambda_handler"
  source_code_hash = filebase64sha256("${path.module}/../lambda/lambda_deployment.zip")
  runtime          = "python3.11"
  timeout          = 180  # 3 minutes for Bedrock agent invocation
  memory_size      = 512

  environment {
    variables = {
      ANALYSES_TABLE        = aws_dynamodb_table.analyses.name
      DAILY_INSIGHTS_TABLE  = aws_dynamodb_table.daily_insights.name
      LAMBDA_PREFIX         = local.prefix
      PREFIX                = local.prefix
      PRODUCT_APPLICATIONS_TABLE = "${local.prefix}-product-applications"
    }
  }

  tags = local.common_tags
}

# CloudWatch Log Group for Personalized Insights Generator
resource "aws_cloudwatch_log_group" "personalized_insights_generator_logs" {
  name              = "/aws/lambda/${aws_lambda_function.personalized_insights_generator.function_name}"
  retention_in_days = 14
  tags              = local.common_tags
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "allow_apigateway_daily_insights" {
  statement_id  = "AllowAPIGatewayInvokeDailyInsights"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.daily_insights_orchestrator.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_apigateway_personalized_insights" {
  statement_id  = "AllowAPIGatewayInvokePersonalizedInsights"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.personalized_insights_generator.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# Lambda permissions for Bedrock Agents to invoke Lambda functions
resource "aws_lambda_permission" "allow_bedrock_daily_insights_orchestrator" {
  statement_id  = "AllowBedrockInvokeDailyInsights"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.daily_insights_orchestrator.function_name
  principal     = "bedrock.amazonaws.com"
  source_arn    = "arn:aws:bedrock:us-east-1:${data.aws_caller_identity.current.account_id}:agent/*"
}

resource "aws_lambda_permission" "allow_bedrock_rag_query_handler" {
  statement_id  = "AllowBedrockInvokeRAGQuery"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rag_query_handler.function_name
  principal     = "bedrock.amazonaws.com"
  source_arn    = "arn:aws:bedrock:us-east-1:${data.aws_caller_identity.current.account_id}:agent/*"
}

# Learning Hub Chatbot Lambda
resource "aws_lambda_function" "learning_hub_chatbot" {
  filename         = "${path.module}/../lambda/lambda_deployment.zip"
  function_name    = "${local.prefix}-learning-hub-chatbot"
  role             = aws_iam_role.additional_lambda_role.arn
  handler          = "learning_hub_handler.lambda_handler"
  source_code_hash = filebase64sha256("${path.module}/../lambda/lambda_deployment.zip")
  runtime          = "python3.11"
  timeout          = 120  # 2 minutes for Bedrock API calls
  memory_size      = 512

  environment {
    variables = {
      CHAT_HISTORY_TABLE       = aws_dynamodb_table.chat_history.name
      EDUCATIONAL_CONTENT_TABLE = aws_dynamodb_table.educational_content.name
      ANALYSES_TABLE           = aws_dynamodb_table.analyses.name
      PRODUCTS_TABLE           = aws_dynamodb_table.products.name
      BEDROCK_MODEL_ID         = "anthropic.claude-3-5-sonnet-20241022"
      LAMBDA_PREFIX            = local.prefix
      PREFIX                   = local.prefix
      RAG_LAMBDA_NAME          = "rag-query-handler"
      AWS_REGION               = data.aws_region.current.name
    }
  }

  tags = local.common_tags
}

# CloudWatch Log Group for Learning Hub Chatbot
resource "aws_cloudwatch_log_group" "learning_hub_chatbot_logs" {
  name              = "/aws/lambda/${aws_lambda_function.learning_hub_chatbot.function_name}"
  retention_in_days = 14
  tags              = local.common_tags
}

# Lambda permission for API Gateway to invoke Learning Hub Chatbot
resource "aws_lambda_permission" "allow_apigateway_learning_hub_chatbot" {
  statement_id  = "AllowAPIGatewayInvokeLearningHubChatbot"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.learning_hub_chatbot.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# Output
output "learning_hub_chatbot_function_name" {
  description = "Name of the Learning Hub Chatbot Lambda function"
  value       = aws_lambda_function.learning_hub_chatbot.function_name
}

output "learning_hub_chatbot_function_arn" {
  description = "ARN of the Learning Hub Chatbot Lambda function"
  value       = aws_lambda_function.learning_hub_chatbot.arn
}

