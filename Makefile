# Makefile for Dokploy Terraform Project
# Provides simplified commands for the deployment workflow.

# Default shell
SHELL := /bin/bash

# Check for required environment variables
BWS_ACCESS_TOKEN ?= $(error BWS_ACCESS_TOKEN is not set. Please export it.)
BWS_PROJECT_ID ?= $(error BWS_PROJECT_ID is not set. Please export it.)

.PHONY: help init plan apply destroy secrets verify clean

help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  help       Show this help message."
	@echo "  init       Initialize Terraform."
	@echo "  plan       Create a Terraform execution plan."
	@echo "  apply      Apply the Terraform plan."
	@echo "  destroy    Destroy the Terraform-managed infrastructure."
	@echo "  secrets    Fetch secrets from Bitwarden and display them."
	@echo "  verify     SSH into the server and run the verification script."
	@echo "  clean      Remove Terraform state and cache files."

init:
	@echo "Initializing Terraform..."
	@terraform init

plan:
	@echo "Creating Terraform plan..."
	@terraform plan

apply:
	@echo "Applying Terraform plan..."
	@terraform apply -auto-approve

destroy:
	@echo "Destroying Terraform infrastructure..."
	@terraform destroy -auto-approve

secrets:
	@echo "Fetching secrets from Bitwarden..."
	@./get-secrets.sh

verify:
	@echo "Verifying installation..."
	@HOSTNAME=$$(terraform output -raw tailscale_hostname); \
	USERNAME=$$(cat terraform.tfvars | grep -m 1 "username" | cut -d '"' -f 2); \
	if [ -z "$$USERNAME" ]; then USERNAME=ubuntu; fi; \
	echo "Copying verification script to $$USERNAME@$$HOSTNAME..."; \
	scp -o StrictHostKeyChecking=no verify-installation.sh $$USERNAME@$$HOSTNAME:~/; \
	echo "Running verification script..."; \
	ssh -o StrictHostKeyChecking=no $$USERNAME@$$HOSTNAME "chmod +x ~/verify-installation.sh && sudo ~/verify-installation.sh"

clean:
	@echo "Cleaning up Terraform files..."
	@rm -f .secrets.json
	@rm -f terraform.tfstate*
	@rm -rf .terraform
