#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_REGION:-eu-south-1}"
PROFILE="${AWS_PROFILE:-manifest}"
CLUSTER="datakeep-production"
SERVICE="${1:-web}"

echo "==> Getting current task definition for ${SERVICE}..."
CURRENT_TD=$(aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "${CLUSTER}-${SERVICE}" \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'services[0].taskDefinition' \
  --output text)

FAMILY=$(echo "$CURRENT_TD" | cut -d/ -f2 | cut -d: -f1)
CURRENT_REV=$(echo "$CURRENT_TD" | cut -d: -f7)
PREV_REV=$((CURRENT_REV - 1))

if [ "$PREV_REV" -lt 1 ]; then
  echo "ERROR: No previous revision to roll back to"
  exit 1
fi

echo "==> Rolling back ${SERVICE}: revision ${CURRENT_REV} -> ${PREV_REV}"
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "${CLUSTER}-${SERVICE}" \
  --task-definition "${FAMILY}:${PREV_REV}" \
  --profile "$PROFILE" \
  --region "$REGION" \
  --no-cli-pager

echo "==> Waiting for service to stabilize..."
aws ecs wait services-stable \
  --cluster "$CLUSTER" \
  --services "${CLUSTER}-${SERVICE}" \
  --profile "$PROFILE" \
  --region "$REGION"

echo "==> Rollback complete!"
