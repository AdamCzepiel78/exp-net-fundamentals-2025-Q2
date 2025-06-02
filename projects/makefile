# CloudFormation Stack Management
STACK_NAME := multi-os-infrastructure
REGION := eu-central-1
BIN_DIR := ./iac-cloud-setup/bin

.PHONY: deploy delete status

deploy: ## Deploy the CloudFormation stack
	chmod +x $(BIN_DIR)/deploy-stack.sh
	cd $(BIN_DIR) && ./deploy-stack.sh

delete: ## Delete the CloudFormation stack
	chmod +x $(BIN_DIR)/delete-stack.sh
	cd $(BIN_DIR) && ./delete-stack.sh

status: ## Show current stack status
	@aws cloudformation describe-stacks --stack-name $(STACK_NAME) --region $(REGION) \
		--query 'Stacks[0].{Name:StackName,Status:StackStatus,Created:CreationTime}' \
		--output table 2>/dev/null || echo "Stack '$(STACK_NAME)' does not exist"