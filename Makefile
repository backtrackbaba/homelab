SHELL := /bin/bash
.DEFAULT_GOAL := help

PROJECT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
ENV_FILE := $(PROJECT_DIR)/.env
RUNTIME_DIR := $(PROJECT_DIR)/.runtime
SOPS_AGE_KEY_FILE ?= $(HOME)/.config/sops/age/keys.txt
SERVICE ?=

.PHONY: help init install-tools age-key sops-config secrets-create secrets-edit secrets-decrypt bootstrap up down restart status ports logs pull update config doctor clean-runtime

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*## "; printf "Usage: make <target>\n\nTargets:\n"} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Create local config files from committed examples
	@test -f $(ENV_FILE) || cp $(PROJECT_DIR)/.env.example $(ENV_FILE)
	@test -f $(PROJECT_DIR)/.sops.yaml || cp $(PROJECT_DIR)/.sops.yaml.example $(PROJECT_DIR)/.sops.yaml
	@mkdir -p $(RUNTIME_DIR)
	@chmod 700 $(RUNTIME_DIR)
	@echo "Initialized $(PROJECT_DIR)"

install-tools: ## Install SOPS and age using Homebrew
	@command -v brew >/dev/null || { echo "Homebrew is required" >&2; exit 1; }
	brew install sops age

age-key: ## Generate an age key and configure SOPS
	@mkdir -p "$(dir $(SOPS_AGE_KEY_FILE))"
	@if test -f "$(SOPS_AGE_KEY_FILE)"; then \
		echo "Age key already exists: $(SOPS_AGE_KEY_FILE)"; \
	else \
		age-keygen -o "$(SOPS_AGE_KEY_FILE)"; \
		chmod 600 "$(SOPS_AGE_KEY_FILE)"; \
	fi
	@$(MAKE) --no-print-directory sops-config

sops-config: init ## Put the local age public key into .sops.yaml
	@command -v age-keygen >/dev/null || { echo "Run: make install-tools" >&2; exit 1; }
	@test -f "$(SOPS_AGE_KEY_FILE)" || { echo "Run: make age-key" >&2; exit 1; }
	@recipient=$$(age-keygen -y "$(SOPS_AGE_KEY_FILE)"); \
	printf 'creation_rules:\n  - path_regex: secrets\\.enc\\.env$$\n    age: %s\n' "$$recipient" > "$(PROJECT_DIR)/.sops.yaml"; \
	echo "Configured .sops.yaml for $$recipient"

secrets-create: init sops-config ## Create encrypted secrets.enc.env from the example
	@command -v sops >/dev/null || { echo "Run: make install-tools" >&2; exit 1; }
	@test -f "$(SOPS_AGE_KEY_FILE)" || { echo "Run: make age-key" >&2; exit 1; }
	@test ! -f $(PROJECT_DIR)/secrets.enc.env || { echo "secrets.enc.env already exists; use make secrets-edit" >&2; exit 1; }
	@set -euo pipefail; \
	tmp=$$(mktemp "$(RUNTIME_DIR)/secrets-create.XXXXXX"); \
	trap 'rm -f "$$tmp" "$(PROJECT_DIR)/secrets.enc.env.tmp"' EXIT; \
	cp "$(PROJECT_DIR)/secrets.example.env" "$$tmp"; \
	SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops --encrypt --filename-override secrets.enc.env "$$tmp" > "$(PROJECT_DIR)/secrets.enc.env.tmp"; \
	test -s "$(PROJECT_DIR)/secrets.enc.env.tmp"; \
	mv "$(PROJECT_DIR)/secrets.enc.env.tmp" "$(PROJECT_DIR)/secrets.enc.env"; \
	echo "Created secrets.enc.env. Run: make secrets-edit"

secrets-edit: ## Edit encrypted secrets safely with SOPS
	@test -f $(PROJECT_DIR)/secrets.enc.env || { echo "Run: make secrets-create" >&2; exit 1; }
	SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops $(PROJECT_DIR)/secrets.enc.env

secrets-decrypt: ## Decrypt secrets into the ignored .runtime directory
	@cd $(PROJECT_DIR) && SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" ./scripts/decrypt-secrets.sh

bootstrap: init ## Create centralized data directories and decrypt secrets
	@cd $(PROJECT_DIR) && SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" ./scripts/bootstrap.sh

up: ## Start all services
	@cd $(PROJECT_DIR) && SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" ./scripts/up.sh

down: ## Stop all services
	@cd $(PROJECT_DIR) && ./scripts/down.sh

restart: down up ## Restart all services

status: ## Show Compose and container status
	@cd $(PROJECT_DIR) && ./scripts/status.sh

ports: ## Show container ports and host bindings
	@cd $(PROJECT_DIR) && ./scripts/ports.sh

logs: ## Follow logs; optionally pass SERVICE=n8n
	@cd $(PROJECT_DIR) && docker compose --env-file .env logs -f $(SERVICE)

pull: ## Pull newer container images
	@cd $(PROJECT_DIR) && docker compose --env-file .env pull

update: pull up ## Pull images and recreate changed services

config: ## Validate and render the Compose configuration
	@cd $(PROJECT_DIR) && SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" ./scripts/decrypt-secrets.sh >/dev/null && \
	set -a && source .runtime/secrets.env && set +a && docker compose --env-file .env config

doctor: ## Check required files, tools, Docker, and configured directories
	@cd $(PROJECT_DIR) && ./scripts/doctor.sh

clean-runtime: ## Delete only decrypted runtime secret files
	@rm -rf $(RUNTIME_DIR)
	@mkdir -p $(RUNTIME_DIR) && chmod 700 $(RUNTIME_DIR)
