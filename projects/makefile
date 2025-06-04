# CloudFormation Stack Management
STACK_NAME := multi-os-infrastructure
REGION := eu-central-1
AWS_BIN_DIR := ./iac-cloud-setup/bin
AZURE_BIN_DIR := ./ipaddressmanagement-azure/azure-iac

.PHONY: deployaws deleteaws statusaws deleteazure deployazure

deployaws: ## Deploy the CloudFormation stack
	chmod +x $(AWS_BIN_DIR)/deploy-stack.sh
	cd $(BIN_DIR) && ./deploy-stack.sh

deleteaws: ## Delete the CloudFormation stack
	chmod +x $(AWS_BIN_DIR)/delete-stack.sh
	cd $(AWS_BIN_DIR) && ./delete-stack.sh

deployazure:
	chmod +x $(AZURE_BIN_DIR)/install-iac.sh
	cd $(AZURE_BIN_DIR) && ./install-iac.sh deploy -g rg-networking-fundamentals


deleteazure:
	chmod +x $(AZURE_BIN_DIR)/install-iac.sh
	cd $(AZURE_BIN_DIR) && ./install-iac.sh delete-resources -g rg-networking-fundamentals

statusaws: ## Show current stack status
	@aws cloudformation describe-stacks --stack-name $(STACK_NAME) --region $(REGION) \
		--query 'Stacks[0].{Name:StackName,Status:StackStatus,Created:CreationTime}' \
		--output table 2>/dev/null || echo "Stack '$(STACK_NAME)' does not exist"