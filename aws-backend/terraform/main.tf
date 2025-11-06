# Lumen AI Skincare Assistant - AWS Infrastructure
# Region: us-east-1
# Terraform >= 1.0

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Variables
variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "lumen-skincare"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "huggingface_api_url" {
  description = "Hugging Face API endpoint"
  type        = string
  default     = "https://Musubi23-skin-analyzer.hf.space/predict"
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Locals
locals {
  prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

