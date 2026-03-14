#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_REGION:-eu-south-1}"
PROFILE="${AWS_PROFILE:-manifest}"
CLUSTER="datakeep-production"

# Get private subnet IDs
SUBNETS=$(aws ec2 describe-subnets \
  --profile "$PROFILE" --region "$REGION" \
  --filters "Name=tag:Name,Values=${CLUSTER}-private-*" \
  --query 'Subnets[*].SubnetId' --output text | tr '\t' ',')

# Get ECS security group ID
SG=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" --region "$REGION" \
  --filters "Name=tag:Name,Values=${CLUSTER}-ecs-sg" \
  --query 'SecurityGroups[0].GroupId' --output text)

echo "==> Running migration task..."
TASK_ARN=$(aws ecs run-task \
  --cluster "$CLUSTER" \
  --task-definition "${CLUSTER}-migrate" \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNETS}],securityGroups=[${SG}],assignPublicIp=DISABLED}" \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'tasks[0].taskArn' \
  --output text)

echo "==> Migration task: $TASK_ARN"
echo "==> Waiting for completion..."

aws ecs wait tasks-stopped \
  --cluster "$CLUSTER" \
  --tasks "$TASK_ARN" \
  --profile "$PROFILE" \
  --region "$REGION"

EXIT_CODE=$(aws ecs describe-tasks \
  --cluster "$CLUSTER" \
  --tasks "$TASK_ARN" \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'tasks[0].containers[0].exitCode' \
  --output text)

if [ "$EXIT_CODE" != "0" ]; then
  echo "ERROR: Migration failed (exit code $EXIT_CODE)"
  echo "Logs: aws logs tail /ecs/datakeep/migrate --profile $PROFILE --region $REGION"
  exit 1
fi

echo "==> Migration completed successfully!"
