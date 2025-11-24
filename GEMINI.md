# GEMINI.md: Project Sancta Via

This document provides a comprehensive overview of the Sancta Via monorepo, its structure, conventions, and operational procedures. It is intended to be a guide for developers and AI agents interacting with the codebase.

## 1. Project Overview

**Sancta Via** is a monorepo containing a suite of Catholic-themed mobile applications developed using the Flutter framework. The project is designed with a modular architecture, promoting code reuse and a consistent user experience across all applications.

### 1.1. Core Technologies

*   **Language:** Dart
*   **Framework:** Flutter
*   **State Management:** Riverpod
*   **Build & CI:** Custom Shell scripts, Makefiles, and `cider` for versioning.

### 1.2. Monorepo Structure

The repository is organized into several distinct types of packages:

*   **Application Packages** (`sancta_via_*_app`): These are the main, runnable Flutter applications.
    *   `sancta_via_bible_reading_app`: A Catholic Bible reading app.
    *   `sancta_via_confession_companion`: A tool to aid in the Sacrament of Penance.
    *   `sancta_via_liturgical_calendar_app`: An app for the liturgical calendar.
    *   `sancta_via_novena_companion`: A companion for praying novenas.
    *   `sancta_via_prayer_companion`: A general prayer application.

*   **Shared Packages** (`sancta_via_shared_*`):
    *   `sancta_via_shared_ui`: A critical library containing shared UI components, widgets, themes (including the `Crimson` font), and a unified settings management system. This package ensures a consistent look-and-feel.

*   **Data Packages** (`sancta_via_*_data`):
    *   `sancta_via_bible_data`: Provides Bible text data, likely from an embedded SQLite database (`assets/bibles.db`).
    *   `sancta_via_liturgical_calendar`: Provides liturgical calendar data. This package has a special build step (`build_data.sh`) that uses a Node.js script to generate its data from `romcal`.

*   **Riverpod Adapter Packages** (`sancta_via_*_riverpod`):
    *   These packages act as a bridge, exposing the data from the `_data` packages to the application frontends via Riverpod providers. This decouples the data layer from the UI and state management logic.

*   **Scripts & Tooling**:
    *   `/build-release.sh`: The primary script for creating production builds of all apps.
    *   `/sancta_via_scripts`: A directory for shared scripts.
    *   `Makefile`: Present in most app directories for common development tasks.

## 2. Building and Running

### 2.1. Prerequisites

*   Flutter SDK (version specified in `pubspec.yaml` files, e.g., `^3.9.2`)
*   Node.js (for building the `sancta_via_liturgical_calendar` data)
*   For iOS builds: macOS with Xcode.

### 2.2. Common Development Commands

Most application directories (`sancta_via_bible_reading_app`, etc.) contain a `Makefile`. Use it for standard tasks.

```bash
# Navigate to an app directory
cd sancta_via_bible_reading_app

# Install dependencies for the current project
make deps

# Run static analysis
make analyze

# Format all Dart code
make format

# Run tests
make test

# Clean build artifacts
make clean

# Run the app on a connected device
flutter run
```

### 2.3. Generating Liturgical Data

The `sancta_via_liturgical_calendar` package requires a data generation step before it can be used.

```bash
cd sancta_via_liturgical_calendar
./build_data.sh
```

### 2.4. Creating a Release Build

The top-level `build-release.sh` script is the authoritative way to build release artifacts for all apps.

```bash
# Perform a dry run to see what will be done
./build-release.sh --dry-run

# Create a new patch release for all apps
./build-release.sh --patch

# Create a new minor release
./build-release.sh --minor
```

This script handles version bumping (using `cider`), building Android APKs/AABs, and building iOS archives. Release artifacts are placed in the `/releases/<timestamp>` directory.

## 3. Development Conventions

The `AGENTS.md` file contains a detailed guide. Key conventions are summarized here.

### 3.1. Code Style

*   **Linter:** A standard `analysis_options.yaml` is used across projects, enforcing strict rules. Find it in any app's root.
*   **Formatting:** Use `dart format .` (or `make format`). Key rules include single quotes, trailing commas, and an 80-character line length.
*   **Imports:** Group imports (dart -> package -> local) and use relative paths for local files.

### 3.2. Architecture

*   **State Management:** All apps use `flutter_riverpod` for state management. Data is exposed from the data layer through providers defined in the `_riverpod` adapter packages.
*   **Unified Settings:** A centralized settings system is provided by `sancta_via_shared_ui`. This was part of a major refactoring (see `MIGRATION_TO_UNIFIED_SETTINGS.md`). New features should use this system for settings like theme, font size, language, etc., to ensure consistency. It includes logic for migrating users' old settings automatically.
*   **Repository Pattern:** The architecture separates UI, business logic, and data sources. Data packages act as repositories.
*   **Error Handling & Logging:** Use the provided `AppLogger` for structured logging. Wrap potentially failing operations in `try/catch` blocks.

### 3.3. Naming Conventions

*   **Classes & Enums:** `PascalCase`
*   **Variables & Functions:** `camelCase`
*   **Constants:** `SCREAMING_SNAKE_CASE`
*   **Private Members:** Prefixed with `_`
