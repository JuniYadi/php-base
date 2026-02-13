# ===============================================
# Multi-Version PHP Base Image - Build Commands
# ===============================================

# Default PHP version
PHP_VERSION ?= 8.4
REGISTRY ?= ghcr.io
IMAGE_NAME ?= $(shell basename $$(git remote get-url origin 2>/dev/null | sed 's/\.git$$//' | sed 's/.*\///') || echo "php-base")
TAG ?= $(PHP_VERSION)

# Get repository owner from git remote
REPO_OWNER ?= $(shell git remote get-url origin 2>/dev/null | sed 's/.*github.com[/:]//' | sed 's/\/.*//' || echo "juniyadi")
FULL_IMAGE = $(REGISTRY)/$(REPO_OWNER)/$(IMAGE_NAME)

.PHONY: build build-all build-push test clean help

# -----------------------------------------------
# Build single PHP version
# -----------------------------------------------
build:
	@echo "Building PHP $(PHP_VERSION)..."
	docker build \
		--build-arg PHP_VERSION=$(PHP_VERSION) \
		-t $(FULL_IMAGE):$(TAG) \
		-t $(FULL_IMAGE):$(PHP_VERSION) \
		-f Dockerfile \
		.

# -----------------------------------------------
# Build and push single PHP version
# -----------------------------------------------
build-push: build
	@echo "Pushing $(FULL_IMAGE):$(TAG)..."
	docker push $(FULL_IMAGE):$(TAG)
	docker push $(FULL_IMAGE):$(PHP_VERSION)

# -----------------------------------------------
# Build all PHP versions (AMD64 only for local)
# -----------------------------------------------
build-all:
	@echo "Building all PHP versions..."
	@for VERSION in 7.4 8.0 8.1 8.2 8.3 8.4 8.5; do \
		echo "=== Building PHP $$VERSION ===" && \
		docker build \
			--build-arg PHP_VERSION=$$VERSION \
			-t $(FULL_IMAGE):$$VERSION \
			-f Dockerfile \
			. || echo "Warning: PHP $$VERSION build failed"; \
	done

# -----------------------------------------------
# Push all PHP versions
# -----------------------------------------------
push-all:
	@echo "Pushing all PHP versions..."
	@for VERSION in 7.4 8.0 8.1 8.2 8.3 8.4 8.5; do \
		if docker image inspect $(FULL_IMAGE):$$VERSION >/dev/null 2>&1; then \
			echo "=== Pushing PHP $$VERSION ===" && \
			docker push $(FULL_IMAGE):$$VERSION; \
		else \
			echo "Image $(FULL_IMAGE):$$VERSION not found, skipping"; \
		fi \
	done

# -----------------------------------------------
# Build multi-platform images
# -----------------------------------------------
build-multiplatform:
	@echo "Building multi-platform images for PHP $(PHP_VERSION)..."
	docker buildx build \
		--build-arg PHP_VERSION=$(PHP_VERSION) \
		--platform linux/amd64,linux/arm64 \
		-t $(FULL_IMAGE):$(TAG)-amd64 \
		-t $(FULL_IMAGE):$(TAG)-arm64 \
		-t $(FULL_IMAGE):$(TAG) \
		--push \
		-f Dockerfile \
		.

# -----------------------------------------------
# Test image functionality
# -----------------------------------------------
test: build
	@echo "Testing PHP $(PHP_VERSION) image..."
	@echo "PHP Version:"
	@docker run --rm $(FULL_IMAGE):$(PHP_VERSION) php -r 'echo PHP_VERSION . "\n";'
	@echo ""
	@echo "Installed Extensions:"
	@docker run --rm $(FULL_IMAGE):$(PHP_VERSION) php -m | head -20

# -----------------------------------------------
# Test MySQL/MariaDB extensions
# -----------------------------------------------
test-mysql: build
	@echo "Testing MySQL/MariaDB extensions in PHP $(PHP_VERSION)..."
	@docker run --rm -v $(PWD)/docs/verify-mysql-extensions.php:/verify.php \
		$(FULL_IMAGE):$(PHP_VERSION) php /verify.php

# -----------------------------------------------
# Shell into the image
# -----------------------------------------------
shell: build
	@echo "Opening shell in PHP $(PHP_VERSION) image..."
	docker run -it --rm $(FULL_IMAGE):$(PHP_VERSION) /bin/sh

# -----------------------------------------------
# Clean up local images
# -----------------------------------------------
clean:
	@echo "Cleaning up local images..."
	@for VERSION in 7.4 8.0 8.1 8.2 8.3 8.4 8.5; do \
		docker rmi $(FULL_IMAGE):$$VERSION 2>/dev/null || true; \
	done
	docker rmi $(FULL_IMAGE):latest 2>/dev/null || true
	docker builder prune -f 2>/dev/null || true

# -----------------------------------------------
# Prune build cache
# -----------------------------------------------
prune:
	@echo "Pruning Docker build cache..."
	docker builder prune -af

# -----------------------------------------------
# Show help
# -----------------------------------------------
help:
	@echo "Multi-Version PHP Base Image Build Commands"
	@echo ""
	@echo "Variables:"
	@echo "  PHP_VERSION  - PHP version to build (default: 8.4)"
	@echo "  REGISTRY     - Container registry (default: ghcr.io)"
	@echo "  IMAGE_NAME   - Image name (default: derived from repo)"
	@echo ""
	@echo "Commands:"
	@echo "  build              - Build single PHP version"
	@echo "  build-push         - Build and push single version"
	@echo "  build-all          - Build all PHP versions (local)"
	@echo "  push-all           - Push all built versions"
	@echo "  build-multiplatform - Build AMD64 + ARM64 and push"
	@echo "  test               - Test built image"
	@echo "  test-mysql         - Test MySQL/MariaDB extensions"
	@echo "  shell              - Open shell in image"
	@echo "  clean              - Remove local images"
	@echo "  prune              - Prune build cache"
	@echo "  help               - Show this help"
	@echo ""
	@echo "Examples:"
	@echo "  make build PHP_VERSION=8.3"
	@echo "  make build-push PHP_VERSION=8.4"
	@echo "  make build-all"
	@echo "  make shell PHP_VERSION=8.4"
