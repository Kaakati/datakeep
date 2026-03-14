#!/bin/bash
# Cleanup all AWS resources in me-central-1
# Run: bash infra/scripts/cleanup-me-central-1.sh

set -euo pipefail
REGION="me-central-1"
VPC_ID="vpc-09837c53f3892cf8e"
IGW_ID="igw-0d58bcf2a82037c3e"

echo "=== Cleaning up me-central-1 ==="

# 1. Delete ECS services
echo "--- Deleting ECS services ---"
for svc in prod-web-service prod-jobs-service; do
  echo "Deleting $svc..."
  aws ecs delete-service --cluster manifest-production --service "$svc" --force --no-cli-pager --region $REGION 2>&1 && echo "  OK" || echo "  FAILED (retry later)"
  sleep 10
done

# 2. Wait for services to drain
echo "--- Waiting 60s for services to drain ---"
sleep 60

# 3. Delete ECS clusters
echo "--- Deleting ECS clusters ---"
for cluster in manifest-production Production; do
  echo "Deleting cluster $cluster..."
  aws ecs delete-cluster --cluster "$cluster" --region $REGION --no-cli-pager 2>&1 | tail -2 && echo "  OK" || echo "  FAILED"
  sleep 5
done

# 4. Deregister task definitions
echo "--- Deregistering task definitions ---"
for family in prod-jobs prod-web; do
  echo "Deregistering $family task definitions..."
  ARNS=$(aws ecs list-task-definitions --family-prefix "$family" --region $REGION --query 'taskDefinitionArns[]' --output text)
  for arn in $ARNS; do
    aws ecs deregister-task-definition --task-definition "$arn" --region $REGION --no-cli-pager >/dev/null 2>&1 || true
    sleep 0.5
  done
  echo "  Done"
done

# 5. Delete target group (may need ALB to finish draining)
echo "--- Deleting target group ---"
aws elbv2 delete-target-group \
  --target-group-arn "arn:aws:elasticloadbalancing:me-central-1:673757068946:targetgroup/manifest-prod-v2/80aa818511941846" \
  --region $REGION 2>&1 && echo "  OK" || echo "  FAILED (retry later)"

# 6. Delete RDS subnet group (after RDS finishes deleting)
echo "--- Deleting RDS subnet group ---"
aws rds delete-db-subnet-group --db-subnet-group-name manifest-db-subnet-group --region $REGION 2>&1 && echo "  OK" || echo "  FAILED (RDS may still be deleting)"

# 7. Delete VPC resources
echo "--- Deleting VPC resources ---"

# Detach and delete IGW
echo "Detaching IGW..."
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION 2>&1 && echo "  Detached" || echo "  Already detached"
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $REGION 2>&1 && echo "  Deleted IGW" || echo "  IGW delete failed"

# Delete subnets
for subnet in subnet-0285210e66cf00659 subnet-03aa52db5fefe3462; do
  echo "Deleting subnet $subnet..."
  aws ec2 delete-subnet --subnet-id $subnet --region $REGION 2>&1 && echo "  OK" || echo "  FAILED"
done

# Delete security groups (not default)
for sg in sg-025687db30cd39fba sg-0690d80adc20e0e8c; do
  echo "Deleting security group $sg..."
  aws ec2 delete-security-group --group-id $sg --region $REGION 2>&1 && echo "  OK" || echo "  FAILED"
done

# Delete non-default route tables
echo "Deleting custom route tables..."
RTS=$(aws ec2 describe-route-tables --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text)
for rt in $RTS; do
  # Disassociate first
  ASSOCS=$(aws ec2 describe-route-tables --route-table-ids $rt --region $REGION --query 'RouteTables[0].Associations[*].RouteTableAssociationId' --output text)
  for assoc in $ASSOCS; do
    aws ec2 disassociate-route-table --association-id $assoc --region $REGION 2>&1 || true
  done
  aws ec2 delete-route-table --route-table-id $rt --region $REGION 2>&1 && echo "  Deleted $rt" || echo "  Failed $rt"
done

# Delete VPC
echo "Deleting VPC..."
aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION 2>&1 && echo "  OK" || echo "  FAILED (check for remaining dependencies)"

echo ""
echo "=== Cleanup complete ==="
echo "If any steps failed, re-run the script after a few minutes."
