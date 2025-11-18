#!/usr/bin/env bash
set -euo pipefail

# Safe teardown script for the model-server infra.
# This will run `terraform destroy` in aws-backend/infra and optionally delete the ECR repository.

INFRA_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)/../infra"
REGION="us-east-1"

echo "This will destroy the ECS/Fargate infra in $INFRA_DIR (us-east-1)."
read -p "Are you sure you want to destroy all resources? Type 'yes' to continue: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Aborting. No changes made.";
  exit 0;
fi

if ! command -v terraform >/dev/null 2>&1; then
  echo "ERROR: terraform not found in PATH" >&2
  exit 1
fi

cd "$INFRA_DIR"

echo "Running: terraform init"
terraform init -input=false

echo "Running: terraform destroy"
terraform destroy -auto-approve

echo "Optionally delete the ECR repository that holds your image." 
read -p "Delete ECR repo lumen-skin-model? (y/N) " DELETE_ECR
if [[ "$DELETE_ECR" =~ ^[Yy]$ ]]; then
  if ! command -v aws >/dev/null 2>&1; then
    echo "ERROR: aws CLI not found; cannot delete ECR repo" >&2
    exit 1
  fi
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region $REGION)
  echo "Deleting ECR repository: $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/lumen-skin-model"
  aws ecr delete-repository --repository-name lumen-skin-model --force --region $REGION
  echo "ECR repository deleted."
fi

echo "Teardown complete."
