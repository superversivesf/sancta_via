# Sancta Via Monorepo

This repository contains all Sancta Via applications and libraries in a single monorepo structure managed with [Melos](https://melos.invertase.dev/).

## Structure

```
sancta_via/                     # Root workspace
├── sancta_via_bible_data/       # Bible data package
├── sancta_via_bible_data_riverpod/ # Riverpod wrapper for Bible data
├── sancta_via_bible_reading_app/ # Bible reading application
├── sancta_via_confession_companion/ # Confession companion app
├── sancta_via_liturgical_calendar/ # Core liturgical calendar package
├── sancta_via_liturgical_calendar_app/ # Liturgical calendar application
├── sancta_via_liturgical_calendar_riverpod/ # Riverpod wrapper for liturgical calendar
├── sancta_via_novena_companion/ # Novena companion app
├── sancta_via_prayer_companion/ # Prayer companion app
├── sancta_via_scripts/          # Shared scripts
├── sancta_via_shared_ui/        # Shared UI components
└── melos.yaml                  # Melos configuration
```

## Setup

1. Install Melos:
   ```bash
   dart pub global activate melos
   ```

2. Bootstrap the workspace:
   ```bash
   melos bootstrap
   ```

## Available Melos Commands

```bash
# Bootstrap all packages
melos bootstrap

# Run static analysis on all packages
melos run analyze

# Format all packages
melos run format

# Run tests in packages that have them
melos run test

# Build Android APKs for all apps
melos run build:android

# Clean all packages
melos run clean
```

## Package Dependencies

Packages reference each other using relative paths, which are automatically managed by Melos during bootstrap. Local changes to shared packages are immediately available to dependent packages.

## Migrating from Previous Structure

This monorepo was created by migrating individual repositories using git subtree merge to preserve full commit history. The previous separate repositories are now archived.