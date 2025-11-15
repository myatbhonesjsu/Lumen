# API Gateway resources for Learning Hub

# /learning-hub resource
resource "aws_api_gateway_resource" "learning_hub" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "learning-hub"
}

# /learning-hub/chat resource
resource "aws_api_gateway_resource" "learning_hub_chat" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.learning_hub.id
  path_part   = "chat"
}

# POST /learning-hub/chat
resource "aws_api_gateway_method" "learning_hub_chat_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.learning_hub_chat.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "learning_hub_chat_post" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.learning_hub_chat.id
  http_method             = aws_api_gateway_method.learning_hub_chat_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${aws_lambda_function.learning_hub_chatbot.arn}/invocations"
}

# OPTIONS /learning-hub/chat (CORS)
resource "aws_api_gateway_method" "learning_hub_chat_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.learning_hub_chat.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "learning_hub_chat_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.learning_hub_chat.id
  http_method = aws_api_gateway_method.learning_hub_chat_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "learning_hub_chat_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.learning_hub_chat.id
  http_method = aws_api_gateway_method.learning_hub_chat_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "learning_hub_chat_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.learning_hub_chat.id
  http_method = aws_api_gateway_method.learning_hub_chat_options.http_method
  status_code = aws_api_gateway_method_response.learning_hub_chat_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# /learning-hub/recommendations resource
resource "aws_api_gateway_resource" "learning_hub_recommendations" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.learning_hub.id
  path_part   = "recommendations"
}

# GET /learning-hub/recommendations
resource "aws_api_gateway_method" "learning_hub_recommendations_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.learning_hub_recommendations.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "learning_hub_recommendations_get" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.learning_hub_recommendations.id
  http_method             = aws_api_gateway_method.learning_hub_recommendations_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${aws_lambda_function.learning_hub_chatbot.arn}/invocations"
}

# /learning-hub/articles resource
resource "aws_api_gateway_resource" "learning_hub_articles" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.learning_hub.id
  path_part   = "articles"
}

# GET /learning-hub/articles
resource "aws_api_gateway_method" "learning_hub_articles_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.learning_hub_articles.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "learning_hub_articles_get" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.learning_hub_articles.id
  http_method             = aws_api_gateway_method.learning_hub_articles_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${aws_lambda_function.learning_hub_chatbot.arn}/invocations"
}

# /learning-hub/chat-history resource
resource "aws_api_gateway_resource" "learning_hub_chat_history" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.learning_hub.id
  path_part   = "chat-history"
}

# GET /learning-hub/chat-history
resource "aws_api_gateway_method" "learning_hub_chat_history_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.learning_hub_chat_history.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "learning_hub_chat_history_get" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.learning_hub_chat_history.id
  http_method             = aws_api_gateway_method.learning_hub_chat_history_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${aws_lambda_function.learning_hub_chatbot.arn}/invocations"
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "learning_hub_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.learning_hub_chatbot.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

