SHELL := /bin/bash
.DEFAULT_GOAL := help

PROJECT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
ENV_FILE := $(PROJECT_DIR)/.env
RUNTIME_DIR := $(PROJECT_DIR)/.runtime
SOPS_AGE_KEY_FILE ?= $(HOME)/.config/sops/age/keys.txt
SERVICE ?=

.PHONY: help init install-tools age-key sops-config secrets-create secrets-edit secrets-decrypt bootstrap up down restart status ports logs pull update config doctor clean-runtime \
	media-up media-down media-logs media-status media-pull media-update \
	photos-up photos-down photos-logs photos-status photos-backup photos-update \
	storage-status

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

media-up: ## Bring up the media automation stack (Sonarr/Radarr/Prowlarr/Bazarr/qBittorrent/Navidrome)
	@cd $(PROJECT_DIR)/stacks/media && \
	test -f .env || cp .env.example .env; \
	set -a; source .env; set +a; \
	mkdir -p "$$APPDATA_ROOT/sonarr" "$$APPDATA_ROOT/radarr" "$$APPDATA_ROOT/prowlarr" "$$APPDATA_ROOT/bazarr" "$$APPDATA_ROOT/qbittorrent" "$$APPDATA_ROOT/navidrome"; \
	mkdir -p "$$MEDIA_ROOT/movies" "$$MEDIA_ROOT/tv" "$$MEDIA_ROOT/music"; \
	mkdir -p "$$DOWNLOAD_ROOT/incomplete" "$$DOWNLOAD_ROOT/complete"; \
	docker compose up -d

media-down: ## Stop the media automation stack
	@cd $(PROJECT_DIR)/stacks/media && docker compose down

media-logs: ## Follow media stack logs; optionally pass SERVICE=sonarr
	@cd $(PROJECT_DIR)/stacks/media && docker compose logs -f $(SERVICE)

media-status: ## Show media stack container status
	@cd $(PROJECT_DIR)/stacks/media && docker compose ps

media-pull: ## Pull newer media stack images
	@cd $(PROJECT_DIR)/stacks/media && docker compose pull

media-update: media-pull media-up ## Pull images and recreate the media stack

photos-up: ## Bring up the Immich photo/video stack
	@cd $(PROJECT_DIR) && SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" ./scripts/decrypt-secrets.sh >/dev/null
	@cd $(PROJECT_DIR)/stacks/photos && \
	test -f .env || cp .env.example .env; \
	set -a; source .env; set +a; \
	mkdir -p "$$UPLOAD_LOCATION" "$$DB_DATA_LOCATION"; \
	DB_PASSWORD="$$(sed -n 's/^IMMICH_DB_PASSWORD=//p' $(RUNTIME_DIR)/secrets.env | tail -n1)" docker compose up -d

photos-down: ## Stop the Immich stack
	@cd $(PROJECT_DIR)/stacks/photos && docker compose down

photos-logs: ## Follow photos stack logs; optionally pass SERVICE=immich-server
	@cd $(PROJECT_DIR)/stacks/photos && docker compose logs -f $(SERVICE)

photos-status: ## Show photos stack container status
	@cd $(PROJECT_DIR)/stacks/photos && docker compose ps

photos-backup: ## Back up the Immich database (originals are not included; see docs)
	@mkdir -p $(PROJECT_DIR)/backups/immich
	@ts=$$(date +%Y%m%d-%H%M%S); \
	docker exec immich_postgres pg_dumpall -U immich | gzip > $(PROJECT_DIR)/backups/immich/immich-$$ts.sql.gz; \
	echo "Backup written to backups/immich/immich-$$ts.sql.gz"

photos-update: photos-backup ## Back up, pull, and recreate the Immich stack (read release notes first)
	@cd $(PROJECT_DIR)/stacks/photos && docker compose pull
	@$(MAKE) --no-print-directory photos-up

storage-status: ## Report host, Docker, and DATA_ROOT disk usage
	@cd $(PROJECT_DIR) && ./scripts/storage-status.sh
