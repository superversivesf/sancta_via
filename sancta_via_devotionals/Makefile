# Devotionals App Build Script

# Configuration
SHELL := /bin/bash
APP_NAME := devotionals
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
	@echo "$(GREEN)Sancta Via Devotionals Build System$(NC)"
	@echo ""
	@echo "Available targets:"
	@echo "  $(YELLOW)info$(NC)            - Show app information"
	@echo "  $(YELLOW)deps$(NC)            - Install dependencies"
	@echo "  $(YELLOW)run$(NC)             - Run on a connected device"
	@echo "  $(YELLOW)run-web$(NC)         - Run in Chrome"
	@echo "  $(YELLOW)build-android$(NC)   - Build Android APK"
	@echo "  $(YELLOW)build-ios$(NC)       - Build iOS (macOS only)"
	@echo "  $(YELLOW)build-web$(NC)       - Build for Web"
	@echo "  $(YELLOW)build-all$(NC)       - Build for all platforms"
	@echo "  $(YELLOW)package$(NC)         - Build all + zip the release"
	@echo "  $(YELLOW)ci$(NC)              - clean + analyze + test + build-all"
	@echo "  $(YELLOW)clean$(NC)           - Clean build artifacts"
	@echo "  $(YELLOW)test$(NC)            - Run tests"
	@echo "  $(YELLOW)analyze$(NC)         - Run static analysis"
	@echo "  $(YELLOW)format$(NC)          - Format code"
	@echo "  $(YELLOW)doctor$(NC)          - Check the Flutter environment"
	@echo "  $(YELLOW)version$(NC)         - Print the app version"
	@echo "  $(YELLOW)import-prayers$(NC)  - Regenerate assets/content/prayers/"
	@echo "  $(YELLOW)sync-engine-packs$(NC) - Copy the 8 engine-fixture packs"
	@echo "  $(YELLOW)embed-packs$(NC)     - Regenerate the wrapper's embedded packs"
	@echo ""
	@echo "Build outputs go to: $(RELEASES_DIR)"

.PHONY: info
info:
	@echo "$(GREEN)Sancta Via Devotionals Information$(NC)"
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

# ── Content regeneration (see README: sources, regeneration, pipeline) ──

# The engine fixtures are the single source of truth for these eight packs.
ENGINE_FIXTURES := ../sancta_via_devotional_engine/test/fixtures/packs

.PHONY: import-prayers
import-prayers: deps
	@echo "$(BLUE)[CONTENT]$(NC) Importing companion prayers..."
	@dart run tool/import_prayers.dart
	@echo "$(GREEN)[SUCCESS]$(NC) assets/content/prayers/ regenerated"

.PHONY: sync-engine-packs
sync-engine-packs:
	@echo "$(BLUE)[CONTENT]$(NC) Copying the eight engine-fixture packs..."
	@for name in angelus divine_mercy_novena five_first_saturdays mercy_hour \
		nine_first_fridays novena_54_day rosary total_consecration; do \
		cp "$(ENGINE_FIXTURES)/$$name.json" "assets/content/packs/$$name.json"; \
	done
	@echo "$(GREEN)[SUCCESS]$(NC) assets/content/packs/ copies refreshed"

.PHONY: embed-packs
embed-packs:
	@echo "$(BLUE)[CONTENT]$(NC) Regenerating the wrapper's embedded packs..."
	@cd ../sancta_via_devotional_engine_riverpod && dart tool/embed_packs.dart
	@echo "$(GREEN)[SUCCESS]$(NC) embedded_packs.dart regenerated"

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
	@echo "$(GREEN)Building Sancta Via Devotionals for all platforms$(NC)"
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
