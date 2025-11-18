#!/usr/bin/env bash
set -euo pipefail

# Deploy script for model-server -> ECR + ECS Fargate (Terraform)
# This script will:
#  - check required tools
#  - build the Docker image
#  - discover AWS account via sts and login to ECR
#  - push image to ECR
#  - write terraform.tfvars for infra and run terraform apply (prompts for confirmation)

ROOT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)/.."
MODEL_DIR="$ROOT_DIR/model-server"
INFRA_DIR="$ROOT_DIR/infra"

IMAGE_NAME="lumen-skin-model"
IMAGE_TAG="latest"
REGION="us-east-1"

check_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "ERROR: $1 is not installed" >&2; exit 1; }
}

echo "Checking prerequisites..."
check_cmd docker
check_cmd aws
check_cmd terraform

echo "Discovering AWS account..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ -z "$ACCOUNT_ID" ]; then
  echo "Could not determine AWS account id. Make sure AWS CLI is configured." >&2
  exit 1
fi

echo "Using AWS Account: $ACCOUNT_ID, Region: $REGION"

cd "$MODEL_DIR"

echo "Building Docker image: $IMAGE_NAME:$IMAGE_TAG"
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .

REPO_URI="$ACCOUNT_ID.dkr.ecr.${REGION}.amazonaws.com/${IMAGE_NAME}"

echo "Ensure ECR repository exists..."
aws ecr describe-repositories --repository-names "$IMAGE_NAME" --region "$REGION" >/dev/null 2>&1 || \
  aws ecr create-repository --repository-name "$IMAGE_NAME" --region "$REGION" >/dev/null

echo "Logging in to ECR..."
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.${REGION}.amazonaws.com"

echo "Tagging and pushing image to ECR: ${REPO_URI}:${IMAGE_TAG}"
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${REPO_URI}:${IMAGE_TAG}
docker push ${REPO_URI}:${IMAGE_TAG}

echo "Preparing Terraform variables..."
mkdir -p "$INFRA_DIR"
cat > "$INFRA_DIR/terraform.tfvars" <<EOF
aws_region = "${REGION}"
account_id = "${ACCOUNT_ID}"
image_tag  = "${IMAGE_TAG}"
EOF

echo "Preparing Terraform plan..."
cd "$INFRA_DIR"
terraform init -upgrade
terraform plan -out=tfplan -var="aws_region=${REGION}"

echo "Terraform plan created (tfplan). Showing plan summary:"
terraform show -no-color tfplan

read -p "Apply this Terraform plan and create/update resources? (y/N) " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Aborting apply. You can review or re-run this script later.";
  exit 0
fi

echo "Applying Terraform plan..."
terraform apply -auto-approve tfplan

echo "Terraform apply complete. Run 'terraform output alb_dns_name' in $INFRA_DIR to get the ALB DNS name."
ALB_DNS=$(terraform output -raw alb_dns_name || terraform output alb_dns_name)

echo "Terraform apply complete. ALB DNS: $ALB_DNS"

read -p "Would you like to automatically update an existing Lambda's CUSTOM_MODEL_URL to point to this ALB? (y/N) " UPDATE_LAMBDA
if [[ "$UPDATE_LAMBDA" =~ ^[Yy]$ ]]; then
  read -p "Enter the Lambda function name to update: " LAMBDA_NAME
  if [ -z "$LAMBDA_NAME" ]; then
    echo "No name provided; skipping Lambda update."
  else
    echo "Updating Lambda function '$LAMBDA_NAME' with CUSTOM_MODEL_URL=http://$ALB_DNS/predict"
    # Run the infra helper script to merge/set env vars (requires aws CLI + python3)
    python3 "$INFRA_DIR/scripts/update_lambda_env.py" "$LAMBDA_NAME" "$ALB_DNS" "$REGION"
  fi
fi

echo "Done. If you skipped Lambda update, set CUSTOM_MODEL_URL manually to: http://<alb_dns_name>/predict"
