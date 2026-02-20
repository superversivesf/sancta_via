# Novena Companion Build Script

# Configuration
SHELL := /bin/bash
APP_NAME := novena_companion
BUILD_DATE := $(shell date +%Y%m%d_%H%M%S)
BUILD_VERSION := $(shell grep "^version:" pubspec.yaml | sed 's/version: *//' | tr -d '"' | cut -d'+' -f1)
BUILD_NUMBER := $(shell grep "^version:" pubspec.yaml | sed 's/version: *//' | tr -d '"' | cut -d'+' -f2)
RELEASES_DIR := ../releases/$(APP_NAME)

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Default target
.PHONY: help
help:
	@echo "$(GREEN)Novena Companion Build System$(NC)"
	@echo ""
	@echo "Available targets:"
	@echo "  $(YELLOW)info$(NC)            - Show app information"
	@echo "  $(YELLOW)deps$(NC)            - Install dependencies"
	@echo "  $(YELLOW)build-all$(NC)       - Build for all platforms"
	@echo "  $(YELLOW)build-android$(NC)   - Build Android APK"
	@echo "  $(YELLOW)build-ios$(NC)       - Build iOS (macOS only)"
	@echo "  $(YELLOW)build-web$(NC)       - Build for Web"
	@echo "  $(YELLOW)clean$(NC)           - Clean build artifacts"
	@echo "  $(YELLOW)test$(NC)            - Run tests"
	@echo "  $(YELLOW)analyze$(NC)         - Run static analysis"
	@echo "  $(YELLOW)format$(NC)          - Format code"
	@echo ""
	@echo "Build outputs go to: $(RELEASES_DIR)"

.PHONY: info
info:
	@echo "$(GREEN)Novena Companion Information$(NC)"
	@echo "App Name: $(APP_NAME)"
	@echo "Version: $(BUILD_VERSION)"
	@echo "Build Number: $(BUILD_NUMBER)"
	@echo "Build Date: $(BUILD_DATE)"
	@echo "Releases Dir: $(RELEASES_DIR)"
	@echo ""
	@echo "Flutter Info:"
	@flutter --version | head -1

.PHONY: deps
deps:
	@echo "$(BLUE)[DEPS]$(NC) Installing dependencies..."
	@flutter pub get
	@echo "$(GREEN)[SUCCESS]$(NC) Dependencies installed"

.PHONY: clean
clean:
	@echo "$(BLUE)[CLEAN]$(NC) Cleaning build artifacts..."
	@flutter clean
	@rm -rf build
	@echo "$(GREEN)[SUCCESS]$(NC) Build artifacts cleaned"

.PHONY: test
test: deps
	@echo "$(BLUE)[TEST]$(NC) Running tests..."
	@flutter test
	@echo "$(GREEN)[SUCCESS]$(NC) Tests completed"

.PHONY: analyze
analyze: deps
	@echo "$(BLUE)[ANALYZE]$(NC) Running static analysis..."
	@flutter analyze
	@echo "$(GREEN)[SUCCESS]$(NC) Analysis completed"

.PHONY: format
format:
	@echo "$(BLUE)[FORMAT]$(NC) Formatting code..."
	@dart format .
	@echo "$(GREEN)[SUCCESS]$(NC) Code formatted"

.PHONY: build-android
build-android: deps
	@echo "$(BLUE)[BUILD]$(NC) Building Android APK..."
	@mkdir -p $(RELEASES_DIR)/android
	@flutter build apk --release
	@if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then \
		cp "build/app/outputs/flutter-apk/app-release.apk" "$(RELEASES_DIR)/android/$(APP_NAME)_v$(BUILD_VERSION)_$(BUILD_DATE).apk"; \
		echo "$(GREEN)[SUCCESS]$(NC) Android APK: $(APP_NAME)_v$(BUILD_VERSION)_$(BUILD_DATE).apk"; \
	else \
		echo "$(RED)[ERROR]$(NC) Android build failed"; \
		exit 1; \
	fi

.PHONY: build-ios
build-ios: deps
	@echo "$(BLUE)[BUILD]$(NC) Building iOS..."
	@if [ "$$(uname)" != "Darwin" ]; then \
		echo "$(RED)[ERROR]$(NC) iOS builds only supported on macOS"; \
		exit 1; \
	fi
	@mkdir -p $(RELEASES_DIR)/ios
	@flutter build ios --release
	@if [ -d "build/ios/Release-iphoneos" ]; then \
		echo "$(GREEN)[SUCCESS]$(NC) iOS build completed"; \
		echo "$(YELLOW)[INFO]$(NC) Use Xcode to create IPA from build/ios/Release-iphoneos/"; \
	else \
		echo "$(RED)[ERROR]$(NC) iOS build failed"; \
		exit 1; \
	fi

.PHONY: build-web
build-web: deps
	@echo "$(BLUE)[BUILD]$(NC) Building Web..."
	@mkdir -p $(RELEASES_DIR)/web
	@flutter build web --release
	@if [ -d "build/web" ]; then \
		cp -r "build/web" "$(RELEASES_DIR)/web/$(APP_NAME)_v$(BUILD_VERSION)_$(BUILD_DATE)_web"; \
		echo "$(GREEN)[SUCCESS]$(NC) Web build: $(APP_NAME)_v$(BUILD_VERSION)_$(BUILD_DATE)_web"; \
	else \
		echo "$(RED)[ERROR]$(NC) Web build failed"; \
		exit 1; \
	fi

.PHONY: build-all
build-all: clean
	@echo "$(GREEN)Building Novena Companion for all platforms$(NC)"
	@echo ""
	@$(MAKE) build-android
	@echo ""
	@if [ "$$(uname)" = "Darwin" ]; then \
		$(MAKE) build-ios; \
		echo ""; \
	fi
	@$(MAKE) build-web
	@echo ""
	@$(MAKE) _update-build-info
	@echo "$(GREEN)[COMPLETE]$(NC) All builds finished!"
	@echo "$(BLUE)[INFO]$(NC) Builds saved to: $(RELEASES_DIR)"

.PHONY: _update-build-info
_update-build-info:
	@mkdir -p ../releases
	@echo "$(BLUE)[INFO]$(NC) Updating build info..."
	@./scripts/update_build_info.sh "$(APP_NAME)" "$(BUILD_VERSION)" "$(BUILD_DATE)" || echo '{"$(APP_NAME)": {"version": "$(BUILD_VERSION)", "build_date": "$(BUILD_DATE)"}}' > ../releases/build_info_$(APP_NAME).json

# Development helpers
.PHONY: run
run: deps
	@echo "$(BLUE)[RUN]$(NC) Starting app..."
	@flutter run

.PHONY: run-web
run-web: deps
	@echo "$(BLUE)[RUN]$(NC) Starting web app..."
	@flutter run -d chrome

.PHONY: doctor
doctor:
	@echo "$(BLUE)[DOCTOR]$(NC) Checking Flutter environment..."
	@flutter doctor

# Release helpers
.PHONY: version
version:
	@echo "$(BUILD_VERSION)"

.PHONY: package
package: build-all
	@echo "$(BLUE)[PACKAGE]$(NC) Creating release package..."
	@cd $(RELEASES_DIR) && zip -r "$(APP_NAME)_v$(BUILD_VERSION)_$(BUILD_DATE).zip" . -x "*.DS_Store"
	@echo "$(GREEN)[SUCCESS]$(NC) Package created: $(RELEASES_DIR)/$(APP_NAME)_v$(BUILD_VERSION)_$(BUILD_DATE).zip"

# CI/CD target
.PHONY: ci
ci: clean analyze test build-all
	@echo "$(GREEN)[CI]$(NC) CI build completed successfully!"
