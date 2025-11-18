variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "account_id" {
  type = string
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "lambda_function_name" {
  type        = string
  description = "(Optional) Existing Lambda function name to update with CUSTOM_MODEL_URL pointing at the ALB DNS. If empty, Terraform will skip updating the Lambda."
  default     = ""
}
