#!/usr/bin/env bash
set -euo pipefail

# Force-update script: build & push latest image to ECR, then trigger ECS force-new-deployment
# Assumes infra already deployed and cluster/service named as in Terraform:
# cluster: lumen-model-cluster
# service: lumen-model-service

REGION="us-east-1"
IMAGE_NAME="lumen-skin-model"
IMAGE_TAG="latest"
ECS_CLUSTER="lumen-model-cluster"
ECS_SERVICE="lumen-model-service"

check_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: $1 is not installed" >&2; exit 1; } }

echo "Checking prerequisites..."
check_cmd docker
check_cmd aws

echo "Discovering AWS account..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region $REGION)
if [ -z "$ACCOUNT_ID" ]; then
  echo "ERROR: could not determine AWS account id" >&2
  exit 1
fi

REPO_URI="$ACCOUNT_ID.dkr.ecr.${REGION}.amazonaws.com/${IMAGE_NAME}"

echo "Building Docker image..."
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .

echo "Ensuring ECR repository exists..."
aws ecr describe-repositories --repository-names "$IMAGE_NAME" --region "$REGION" >/dev/null 2>&1 || \
  aws ecr create-repository --repository-name "$IMAGE_NAME" --region "$REGION"

echo "Logging in to ECR..."
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.${REGION}.amazonaws.com"

echo "Tagging and pushing image: ${REPO_URI}:${IMAGE_TAG}"
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${REPO_URI}:${IMAGE_TAG}
docker push ${REPO_URI}:${IMAGE_TAG}

echo "Triggering ECS rolling deploy (force new deployment)..."
aws ecs update-service --cluster ${ECS_CLUSTER} --service ${ECS_SERVICE} --force-new-deployment --region ${REGION}

echo "Force update triggered. Monitor tasks in ECS console or via 'aws ecs describe-services'."
