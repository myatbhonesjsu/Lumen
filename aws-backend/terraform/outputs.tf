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
  description = "Skin Analysis API Gateway endpoint URL"
  value       = "${aws_api_gateway_stage.main.invoke_url}/"
}

output "learning_hub_api_endpoint" {
  description = "Learning Hub API Gateway endpoint URL"
  value       = "${aws_api_gateway_stage.learning_hub.invoke_url}/"
}

output "s3_bucket_images" {
  description = "S3 bucket for image uploads"
  value       = aws_s3_bucket.images.bucket
}

output "lambda_function" {
  description = "Skin Analysis Lambda function name"
  value       = aws_lambda_function.analyze_skin.function_name
}

output "learning_hub_lambda_function" {
  description = "Learning Hub Lambda function name"
  value       = aws_lambda_function.learning_hub_chatbot.function_name
}

output "next_steps" {
  description = "Next steps for completion"
  value       = <<-EOT

    ✅ Infrastructure deployed successfully!

    Next steps:
    1. Update iOS app with API endpoints:
       • Skin Analysis: ${aws_api_gateway_stage.main.invoke_url}/
       • Learning Hub: ${aws_api_gateway_stage.learning_hub.invoke_url}/

    2. Test APIs:
       • curl ${aws_api_gateway_stage.main.invoke_url}/upload-image
       • curl ${aws_api_gateway_stage.learning_hub.invoke_url}/articles

    3. Optional: Setup Knowledge Base for enhanced AI responses
       • cd scripts && python3 setup-knowledge-base.py

    See aws-backend/README.md for detailed instructions.
  EOT
}

