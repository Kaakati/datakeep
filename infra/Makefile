REGION  ?= eu-south-1
PROFILE ?= manifest
CLUSTER ?= datakeep-production
DOMAIN  ?= datakeep.ai
TAG     ?= latest

ACCOUNT_ID := $(shell aws sts get-caller-identity --profile $(PROFILE) --query Account --output text 2>/dev/null)
ECR_URL    := $(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com

.PHONY: init plan apply destroy cert ecr-login deploy migrate rollback \
        logs-web logs-jobs shell

# --- Terraform ---

init:
	cd terraform && terraform init

plan:
	cd terraform && terraform plan

apply:
	cd terraform && terraform apply

destroy:
	cd terraform && terraform destroy

# --- ACM Certificate (run before first apply) ---

cert:
	@echo "==> Requesting ACM certificate for $(DOMAIN)..."
	@aws acm request-certificate \
		--domain-name $(DOMAIN) \
		--validation-method DNS \
		--profile $(PROFILE) \
		--region $(REGION)
	@echo ""
	@echo "Next steps:"
	@echo "  1. Run: aws acm list-certificates --profile $(PROFILE) --region $(REGION)"
	@echo "  2. Run: aws acm describe-certificate --certificate-arn <ARN> --profile $(PROFILE) --region $(REGION)"
	@echo "  3. Add the CNAME validation record in Cloudflare"
	@echo "  4. Set certificate_arn in terraform/terraform.tfvars"
	@echo "  5. Run: make apply"

# --- Docker / ECR ---

ecr-login:
	aws ecr get-login-password --region $(REGION) --profile $(PROFILE) | \
		docker login --username AWS --password-stdin $(ECR_URL)

deploy:
	./scripts/deploy.sh $(TAG)

migrate:
	./scripts/migrate.sh

rollback:
	./scripts/rollback.sh $(filter-out $@,$(MAKECMDGOALS))

# --- Logs & Debugging ---

logs-web:
	aws logs tail /ecs/datakeep/web --follow --profile $(PROFILE) --region $(REGION)

logs-jobs:
	aws logs tail /ecs/datakeep/jobs --follow --profile $(PROFILE) --region $(REGION)

logs-migrate:
	aws logs tail /ecs/datakeep/migrate --follow --profile $(PROFILE) --region $(REGION)

shell:
	@test -n "$(TASK)" || (echo "Usage: make shell TASK=<task-id> [CONTAINER=web|jobs]" && exit 1)
	aws ecs execute-command \
		--cluster $(CLUSTER) \
		--task $(TASK) \
		--container $(or $(CONTAINER),web) \
		--interactive \
		--command "/bin/bash" \
		--profile $(PROFILE) \
		--region $(REGION)

# --- Secrets (first-time setup) ---

set-master-key:
	@test -f ../../config/master.key || (echo "config/master.key not found" && exit 1)
	aws secretsmanager put-secret-value \
		--secret-id datakeep/rails-master-key \
		--secret-string "$$(cat ../../config/master.key)" \
		--profile $(PROFILE) \
		--region $(REGION)
	@echo "==> Rails master key set"

set-stripe-keys:
	@test -n "$(STRIPE_KEY)" || (echo "Usage: make set-stripe-keys STRIPE_KEY=sk_live_... STRIPE_WEBHOOK=whsec_..." && exit 1)
	aws secretsmanager put-secret-value \
		--secret-id datakeep/stripe-secret-key \
		--secret-string "$(STRIPE_KEY)" \
		--profile $(PROFILE) \
		--region $(REGION)
	aws secretsmanager put-secret-value \
		--secret-id datakeep/stripe-webhook-secret \
		--secret-string "$(STRIPE_WEBHOOK)" \
		--profile $(PROFILE) \
		--region $(REGION)
	@echo "==> Stripe keys set"
