#!/usr/bin/env bash
set -euo pipefail

TAG="${1:-latest}"
REGION="${AWS_REGION:-eu-south-1}"
PROFILE="${AWS_PROFILE:-manifest}"
CLUSTER="datakeep-production"
ECR_REPO="datakeep"

ACCOUNT_ID=$(aws sts get-caller-identity --profile "$PROFILE" --query Account --output text)
ECR_URL="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPO}"

echo "==> Building Docker image..."
docker build -t "${ECR_REPO}:${TAG}" -f ../../Dockerfile ../..

echo "==> Tagging image..."
docker tag "${ECR_REPO}:${TAG}" "${ECR_URL}:${TAG}"
docker tag "${ECR_REPO}:${TAG}" "${ECR_URL}:latest"

echo "==> Pushing to ECR..."
docker push "${ECR_URL}:${TAG}"
docker push "${ECR_URL}:latest"

echo "==> Running migrations..."
"$(dirname "$0")/migrate.sh"

echo "==> Updating web service..."
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "${CLUSTER}-web" \
  --force-new-deployment \
  --profile "$PROFILE" \
  --region "$REGION" \
  --no-cli-pager

echo "==> Updating jobs service..."
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "${CLUSTER}-jobs" \
  --force-new-deployment \
  --profile "$PROFILE" \
  --region "$REGION" \
  --no-cli-pager

echo "==> Waiting for web service to stabilize..."
aws ecs wait services-stable \
  --cluster "$CLUSTER" \
  --services "${CLUSTER}-web" \
  --profile "$PROFILE" \
  --region "$REGION"

echo "==> Deploy complete! Tag: ${TAG}"
