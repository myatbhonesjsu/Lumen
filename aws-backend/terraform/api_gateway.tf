# API Gateway REST API

resource "aws_api_gateway_rest_api" "main" {
  name        = "${local.prefix}-api"
  description = "Lumen Skincare Analysis API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.common_tags
}

# Cognito Authorizer
resource "aws_api_gateway_authorizer" "cognito" {
  name            = "${local.prefix}-cognito-authorizer"
  rest_api_id     = aws_api_gateway_rest_api.main.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [aws_cognito_user_pool.main.arn]
  identity_source = "method.request.header.Authorization"
}

# API Gateway Resources and Methods

# /upload-image endpoint
resource "aws_api_gateway_resource" "upload" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "upload-image"
}

resource "aws_api_gateway_method" "upload_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.upload.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "upload_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.upload.id
  http_method = aws_api_gateway_method.upload_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.analyze_skin.invoke_arn
}

# /analysis/{id} endpoint
resource "aws_api_gateway_resource" "analysis" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "analysis"
}

resource "aws_api_gateway_resource" "analysis_id" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.analysis.id
  path_part   = "{id}"
}

resource "aws_api_gateway_method" "analysis_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.analysis_id.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "analysis_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.analysis_id.id
  http_method = aws_api_gateway_method.analysis_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.analyze_skin.invoke_arn
}

# /products/recommendations endpoint
resource "aws_api_gateway_resource" "products" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "products"
}

resource "aws_api_gateway_resource" "recommendations" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.products.id
  path_part   = "recommendations"
}

resource "aws_api_gateway_method" "recommendations_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.recommendations.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "recommendations_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.recommendations.id
  http_method = aws_api_gateway_method.recommendations_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.analyze_skin.invoke_arn
}

# /daily-insights endpoints
resource "aws_api_gateway_resource" "daily_insights" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "daily-insights"
}

# POST /daily-insights/generate - Generate new daily insight
resource "aws_api_gateway_resource" "daily_insights_generate" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.daily_insights.id
  path_part   = "generate"
}

resource "aws_api_gateway_method" "daily_insights_generate_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.daily_insights_generate.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "daily_insights_generate_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.daily_insights_generate.id
  http_method = aws_api_gateway_method.daily_insights_generate_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.daily_insights_orchestrator.invoke_arn
}

# GET /daily-insights/latest - Get latest daily insight
resource "aws_api_gateway_resource" "daily_insights_latest" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.daily_insights.id
  path_part   = "latest"
}

resource "aws_api_gateway_method" "daily_insights_latest_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.daily_insights_latest.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "daily_insights_latest_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.daily_insights_latest.id
  http_method = aws_api_gateway_method.daily_insights_latest_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.daily_insights_orchestrator.invoke_arn
}

# POST /daily-insights/checkin - Submit check-in response
resource "aws_api_gateway_resource" "daily_insights_checkin" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.daily_insights.id
  path_part   = "checkin"
}

resource "aws_api_gateway_method" "daily_insights_checkin_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.daily_insights_checkin.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "daily_insights_checkin_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.daily_insights_checkin.id
  http_method = aws_api_gateway_method.daily_insights_checkin_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.daily_insights_orchestrator.invoke_arn
}

# POST /daily-insights/products/apply - Submit product applications
resource "aws_api_gateway_resource" "daily_insights_products" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.daily_insights.id
  path_part   = "products"
}

resource "aws_api_gateway_resource" "daily_insights_products_apply" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.daily_insights_products.id
  path_part   = "apply"
}

resource "aws_api_gateway_method" "daily_insights_products_apply_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.daily_insights_products_apply.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "daily_insights_products_apply_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.daily_insights_products_apply.id
  http_method = aws_api_gateway_method.daily_insights_products_apply_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.daily_insights_orchestrator.invoke_arn
}

# /agent-chat endpoints - Direct agent invocation with conversational responses
resource "aws_api_gateway_resource" "agent_chat" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "agent-chat"
}

# /agent-chat/skin-analyst
resource "aws_api_gateway_resource" "agent_chat_skin_analyst" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.agent_chat.id
  path_part   = "skin-analyst"
}

resource "aws_api_gateway_method" "agent_chat_skin_analyst_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.agent_chat_skin_analyst.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "agent_chat_skin_analyst_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.agent_chat_skin_analyst.id
  http_method = aws_api_gateway_method.agent_chat_skin_analyst_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.personalized_insights_generator.invoke_arn
}

# /agent-chat/routine-coach
resource "aws_api_gateway_resource" "agent_chat_routine_coach" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.agent_chat.id
  path_part   = "routine-coach"
}

resource "aws_api_gateway_method" "agent_chat_routine_coach_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.agent_chat_routine_coach.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "agent_chat_routine_coach_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.agent_chat_routine_coach.id
  http_method = aws_api_gateway_method.agent_chat_routine_coach_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.personalized_insights_generator.invoke_arn
}

# CORS configuration
module "cors_upload" {
  source = "squidfunk/api-gateway-enable-cors/aws"
  version = "0.3.3"

  api_id          = aws_api_gateway_rest_api.main.id
  api_resource_id = aws_api_gateway_resource.upload.id
}

module "cors_analysis" {
  source = "squidfunk/api-gateway-enable-cors/aws"
  version = "0.3.3"

  api_id          = aws_api_gateway_rest_api.main.id
  api_resource_id = aws_api_gateway_resource.analysis_id.id
}

module "cors_recommendations" {
  source = "squidfunk/api-gateway-enable-cors/aws"
  version = "0.3.3"

  api_id          = aws_api_gateway_rest_api.main.id
  api_resource_id = aws_api_gateway_resource.recommendations.id
}

module "cors_daily_insights_generate" {
  source = "squidfunk/api-gateway-enable-cors/aws"
  version = "0.3.3"

  api_id          = aws_api_gateway_rest_api.main.id
  api_resource_id = aws_api_gateway_resource.daily_insights_generate.id
}

module "cors_daily_insights_latest" {
  source = "squidfunk/api-gateway-enable-cors/aws"
  version = "0.3.3"

  api_id          = aws_api_gateway_rest_api.main.id
  api_resource_id = aws_api_gateway_resource.daily_insights_latest.id
}

module "cors_daily_insights_checkin" {
  source = "squidfunk/api-gateway-enable-cors/aws"
  version = "0.3.3"

  api_id          = aws_api_gateway_rest_api.main.id
  api_resource_id = aws_api_gateway_resource.daily_insights_checkin.id
}

module "cors_daily_insights_products_apply" {
  source = "squidfunk/api-gateway-enable-cors/aws"
  version = "0.3.3"

  api_id          = aws_api_gateway_rest_api.main.id
  api_resource_id = aws_api_gateway_resource.daily_insights_products_apply.id
}

module "cors_agent_chat_skin_analyst" {
  source = "squidfunk/api-gateway-enable-cors/aws"
  version = "0.3.3"

  api_id          = aws_api_gateway_rest_api.main.id
  api_resource_id = aws_api_gateway_resource.agent_chat_skin_analyst.id
}

module "cors_agent_chat_routine_coach" {
  source = "squidfunk/api-gateway-enable-cors/aws"
  version = "0.3.3"

  api_id          = aws_api_gateway_rest_api.main.id
  api_resource_id = aws_api_gateway_resource.agent_chat_routine_coach.id
}

# Deployment
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.upload.id,
      aws_api_gateway_method.upload_post.id,
      aws_api_gateway_integration.upload_lambda.id,
      aws_api_gateway_resource.analysis_id.id,
      aws_api_gateway_method.analysis_get.id,
      aws_api_gateway_integration.analysis_lambda.id,
      aws_api_gateway_resource.recommendations.id,
      aws_api_gateway_method.recommendations_get.id,
      aws_api_gateway_integration.recommendations_lambda.id,
      aws_api_gateway_resource.daily_insights_generate.id,
      aws_api_gateway_method.daily_insights_generate_post.id,
      aws_api_gateway_integration.daily_insights_generate_lambda.id,
      aws_api_gateway_resource.daily_insights_latest.id,
      aws_api_gateway_method.daily_insights_latest_get.id,
      aws_api_gateway_integration.daily_insights_latest_lambda.id,
      aws_api_gateway_resource.daily_insights_checkin.id,
      aws_api_gateway_method.daily_insights_checkin_post.id,
      aws_api_gateway_integration.daily_insights_checkin_lambda.id,
      aws_api_gateway_resource.daily_insights_products_apply.id,
      aws_api_gateway_method.daily_insights_products_apply_post.id,
      aws_api_gateway_integration.daily_insights_products_apply_lambda.id,
      aws_api_gateway_resource.agent_chat_skin_analyst.id,
      aws_api_gateway_method.agent_chat_skin_analyst_post.id,
      aws_api_gateway_integration.agent_chat_skin_analyst_lambda.id,
      aws_api_gateway_resource.agent_chat_routine_coach.id,
      aws_api_gateway_method.agent_chat_routine_coach_post.id,
      aws_api_gateway_integration.agent_chat_routine_coach_lambda.id,
      aws_api_gateway_resource.learning_hub_articles.id,
      aws_api_gateway_method.learning_hub_articles_get.id,
      aws_api_gateway_integration.learning_hub_articles_lambda.id,
      aws_api_gateway_resource.learning_hub_recommendations.id,
      aws_api_gateway_method.learning_hub_recommendations_get.id,
      aws_api_gateway_integration.learning_hub_recommendations_lambda.id,
      aws_api_gateway_resource.learning_hub_chat.id,
      aws_api_gateway_method.learning_hub_chat_post.id,
      aws_api_gateway_integration.learning_hub_chat_lambda.id,
      aws_api_gateway_resource.learning_hub_chat_history.id,
      aws_api_gateway_method.learning_hub_chat_history_get.id,
      aws_api_gateway_integration.learning_hub_chat_history_lambda.id,
      aws_api_gateway_resource.learning_hub_suggestions.id,
      aws_api_gateway_method.learning_hub_suggestions_get.id,
      aws_api_gateway_integration.learning_hub_suggestions_lambda.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.upload_lambda,
    aws_api_gateway_integration.analysis_lambda,
    aws_api_gateway_integration.recommendations_lambda,
    aws_api_gateway_integration.daily_insights_generate_lambda,
    aws_api_gateway_integration.daily_insights_latest_lambda,
    aws_api_gateway_integration.daily_insights_checkin_lambda,
    aws_api_gateway_integration.daily_insights_products_apply_lambda,
    aws_api_gateway_integration.learning_hub_articles_lambda,
    aws_api_gateway_integration.learning_hub_recommendations_lambda,
    aws_api_gateway_integration.learning_hub_chat_lambda,
    aws_api_gateway_integration.learning_hub_chat_history_lambda,
    aws_api_gateway_integration.learning_hub_suggestions_lambda
  ]
}

# Stage
resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment

  xray_tracing_enabled = true

  tags = local.common_tags
}

# Usage plan for throttling
resource "aws_api_gateway_usage_plan" "main" {
  name = "${local.prefix}-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
  }

  throttle_settings {
    burst_limit = 100
    rate_limit  = 50
  }

  quota_settings {
    limit  = 10000
    period = "DAY"
  }
}

# /learning-hub endpoints - Educational articles and AI chat
resource "aws_api_gateway_resource" "learning_hub" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "learning-hub"
}

# /learning-hub/articles
resource "aws_api_gateway_resource" "learning_hub_articles" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.learning_hub.id
  path_part   = "articles"
}

resource "aws_api_gateway_method" "learning_hub_articles_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.learning_hub_articles.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "learning_hub_articles_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.learning_hub_articles.id
  http_method = aws_api_gateway_method.learning_hub_articles_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.learning_hub_chatbot.invoke_arn
}

# /learning-hub/recommendations
resource "aws_api_gateway_resource" "learning_hub_recommendations" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.learning_hub.id
  path_part   = "recommendations"
}

resource "aws_api_gateway_method" "learning_hub_recommendations_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.learning_hub_recommendations.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "learning_hub_recommendations_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.learning_hub_recommendations.id
  http_method = aws_api_gateway_method.learning_hub_recommendations_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.learning_hub_chatbot.invoke_arn
}

# /learning-hub/chat
resource "aws_api_gateway_resource" "learning_hub_chat" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.learning_hub.id
  path_part   = "chat"
}

resource "aws_api_gateway_method" "learning_hub_chat_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.learning_hub_chat.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "learning_hub_chat_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.learning_hub_chat.id
  http_method = aws_api_gateway_method.learning_hub_chat_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.learning_hub_chatbot.invoke_arn
}

# /learning-hub/chat-history
resource "aws_api_gateway_resource" "learning_hub_chat_history" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.learning_hub.id
  path_part   = "chat-history"
}

resource "aws_api_gateway_method" "learning_hub_chat_history_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.learning_hub_chat_history.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "learning_hub_chat_history_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.learning_hub_chat_history.id
  http_method = aws_api_gateway_method.learning_hub_chat_history_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.learning_hub_chatbot.invoke_arn
}

# /learning-hub/suggestions
resource "aws_api_gateway_resource" "learning_hub_suggestions" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.learning_hub.id
  path_part   = "suggestions"
}

resource "aws_api_gateway_method" "learning_hub_suggestions_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.learning_hub_suggestions.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "learning_hub_suggestions_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.learning_hub_suggestions.id
  http_method = aws_api_gateway_method.learning_hub_suggestions_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.learning_hub_chatbot.invoke_arn
}

# CORS for Learning Hub endpoints
module "cors_learning_hub_articles" {
  source = "squidfunk/api-gateway-enable-cors/aws"
  version = "0.3.3"

  api_id          = aws_api_gateway_rest_api.main.id
  api_resource_id = aws_api_gateway_resource.learning_hub_articles.id
}

module "cors_learning_hub_recommendations" {
  source = "squidfunk/api-gateway-enable-cors/aws"
  version = "0.3.3"

  api_id          = aws_api_gateway_rest_api.main.id
  api_resource_id = aws_api_gateway_resource.learning_hub_recommendations.id
}

module "cors_learning_hub_chat" {
  source = "squidfunk/api-gateway-enable-cors/aws"
  version = "0.3.3"

  api_id          = aws_api_gateway_rest_api.main.id
  api_resource_id = aws_api_gateway_resource.learning_hub_chat.id
}

module "cors_learning_hub_chat_history" {
  source = "squidfunk/api-gateway-enable-cors/aws"
  version = "0.3.3"

  api_id          = aws_api_gateway_rest_api.main.id
  api_resource_id = aws_api_gateway_resource.learning_hub_chat_history.id
}

module "cors_learning_hub_suggestions" {
  source = "squidfunk/api-gateway-enable-cors/aws"
  version = "0.3.3"

  api_id          = aws_api_gateway_rest_api.main.id
  api_resource_id = aws_api_gateway_resource.learning_hub_suggestions.id
}

# Outputs
output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_api_gateway_rest_api.main.id
}

