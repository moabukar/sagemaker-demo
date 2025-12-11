.PHONY: help install install-dev clean test lint format tf-init tf-plan tf-apply tf-destroy pre-commit

# Variables
PYTHON := python3.11
VENV := .venv
TERRAFORM_DIR := terraform
SCRIPTS_DIR := scripts

# Colours
COLOUR_GREEN := \033[0;32m
COLOUR_YELLOW := \033[0;33m
COLOUR_RED := \033[0;31m
COLOUR_RESET := \033[0m

help: ## Show this help message
	@echo "$(COLOUR_GREEN)Available targets:$(COLOUR_RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(COLOUR_YELLOW)%-20s$(COLOUR_RESET) %s\n", $$1, $$2}'

install: ## Install production dependencies
	@echo "$(COLOUR_GREEN)Installing production dependencies...$(COLOUR_RESET)"
	$(PYTHON) -m pip install --upgrade pip
	$(PYTHON) -m pip install -r requirements.txt

install-dev: ## Install development dependencies
	@echo "$(COLOUR_GREEN)Installing development dependencies...$(COLOUR_RESET)"
	$(PYTHON) -m pip install --upgrade pip
	$(PYTHON) -m pip install -r requirements-dev.txt
	pre-commit install
	pre-commit install --hook-type commit-msg

clean: ## Clean temporary files and caches
	@echo "$(COLOUR_GREEN)Cleaning temporary files...$(COLOUR_RESET)"
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.pyo" -delete
	find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".mypy_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".coverage" -exec rm -rf {} + 2>/dev/null || true
	rm -rf build/ dist/ htmlcov/ .tox/

test: ## Run tests
	@echo "$(COLOUR_GREEN)Running tests...$(COLOUR_RESET)"
	pytest tests/ -v --cov=$(SCRIPTS_DIR) --cov-report=html --cov-report=term-missing

test-unit: ## Run unit tests only
	@echo "$(COLOUR_GREEN)Running unit tests...$(COLOUR_RESET)"
	pytest tests/unit/ -v

test-integration: ## Run integration tests only
	@echo "$(COLOUR_GREEN)Running integration tests...$(COLOUR_RESET)"
	pytest tests/integration/ -v

lint: ## Run linters
	@echo "$(COLOUR_GREEN)Running linters...$(COLOUR_RESET)"
	flake8 $(SCRIPTS_DIR) tests/
	mypy $(SCRIPTS_DIR)
	bandit -r $(SCRIPTS_DIR) -c pyproject.toml

format: ## Format code
	@echo "$(COLOUR_GREEN)Formatting code...$(COLOUR_RESET)"
	black $(SCRIPTS_DIR) tests/
	isort $(SCRIPTS_DIR) tests/

format-check: ## Check code formatting without modifying
	@echo "$(COLOUR_GREEN)Checking code formatting...$(COLOUR_RESET)"
	black --check $(SCRIPTS_DIR) tests/
	isort --check-only $(SCRIPTS_DIR) tests/

security: ## Run security checks
	@echo "$(COLOUR_GREEN)Running security checks...$(COLOUR_RESET)"
	bandit -r $(SCRIPTS_DIR) -c pyproject.toml
	detect-secrets scan --baseline .secrets.baseline

tf-init: ## Initialize Terraform
	@echo "$(COLOUR_GREEN)Initializing Terraform...$(COLOUR_RESET)"
	cd $(TERRAFORM_DIR) && terraform init

tf-validate: ## Validate Terraform configuration
	@echo "$(COLOUR_GREEN)Validating Terraform...$(COLOUR_RESET)"
	cd $(TERRAFORM_DIR) && terraform validate

tf-fmt: ## Format Terraform files
	@echo "$(COLOUR_GREEN)Formatting Terraform files...$(COLOUR_RESET)"
	cd $(TERRAFORM_DIR) && terraform fmt -recursive

tf-plan: ## Run Terraform plan
	@echo "$(COLOUR_GREEN)Running Terraform plan...$(COLOUR_RESET)"
	cd $(TERRAFORM_DIR) && terraform plan

tf-apply: ## Apply Terraform configuration
	@echo "$(COLOUR_YELLOW)Applying Terraform configuration...$(COLOUR_RESET)"
	cd $(TERRAFORM_DIR) && terraform apply

tf-destroy: ## Destroy Terraform resources
	@echo "$(COLOUR_RED)Destroying Terraform resources...$(COLOUR_RESET)"
	cd $(TERRAFORM_DIR) && terraform destroy

tf-output: ## Show Terraform outputs
	@echo "$(COLOUR_GREEN)Terraform outputs:$(COLOUR_RESET)"
	cd $(TERRAFORM_DIR) && terraform output -json

pre-commit: ## Run pre-commit hooks on all files
	@echo "$(COLOUR_GREEN)Running pre-commit hooks...$(COLOUR_RESET)"
	pre-commit run --all-files

demo: ## Run the demo script
	@echo "$(COLOUR_GREEN)Running demo...$(COLOUR_RESET)"
	@if [ -z "$(BUCKET)" ]; then echo "$(COLOUR_RED)Error: BUCKET variable not set$(COLOUR_RESET)"; exit 1; fi
	@if [ -z "$(ROLE_ARN)" ]; then echo "$(COLOUR_RED)Error: ROLE_ARN variable not set$(COLOUR_RESET)"; exit 1; fi
	$(PYTHON) $(SCRIPTS_DIR)/demo.py --bucket $(BUCKET) --role-arn $(ROLE_ARN) --region $(REGION)

setup: install-dev tf-init ## Complete setup (install deps + init Terraform)
	@echo "$(COLOUR_GREEN)Setup complete!$(COLOUR_RESET)"

ci: format-check lint test security ## Run all CI checks
	@echo "$(COLOUR_GREEN)All CI checks passed!$(COLOUR_RESET)"

.DEFAULT_GOAL := help
