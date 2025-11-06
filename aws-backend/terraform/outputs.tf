# Terraform Outputs

output "region" {
  description = "AWS region"
  value       = data.aws_region.current.name
}

output "account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = "${aws_api_gateway_stage.main.invoke_url}/"
}

output "s3_bucket_images" {
  description = "S3 bucket for image uploads"
  value       = aws_s3_bucket.images.bucket
}

output "lambda_function" {
  description = "Lambda function name"
  value       = aws_lambda_function.analyze_skin.function_name
}

output "next_steps" {
  description = "Next steps for completion"
  value       = <<-EOT
    
    ✅ Infrastructure deployed successfully!
    
    Next steps:
    1. Create Bedrock Agent in AWS Console
    2. Update Lambda environment variable BEDROCK_AGENT_ID
    3. Load products into DynamoDB: npm run load-products
    4. Test API: curl ${aws_api_gateway_stage.main.invoke_url}/upload-image
    5. Update iOS app with API endpoint: ${aws_api_gateway_stage.main.invoke_url}
    
    See aws-backend/README.md for detailed instructions.
  EOT
}

