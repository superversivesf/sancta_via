# Sancta Via Saints App

A focused Catholic saints companion application with searchable saint profiles, category browsing, favorites, and detailed feast-day information. This is a standalone Flutter app that utilizes the Sancta Via ecosystem packages hosted on GitHub.

## 🎯 Features

- **Saint Profiles** - Detailed biographies, patronages, and feast days
- **Category Browsing** - Explore saints grouped by patronage and themes
- **Saint Search** - Fast full-text search across the saint dataset
- **Favorites** - Save the saints you pray with most
- **Liturgical Theming** - App colors adapt to the current liturgical season
- **Feast-Day Awareness** - Today's saints surfaced from the shared dataset

## 🗄️ Saint Data

- **Shared SQLite dataset** - Maintained in the `sancta_via_saint_data` package
- **Full-text search** - FTS-backed saint, category, and feast lookup
- **Cached access** - Repository pattern with built-in caching

## 🏗️ Architecture

This app is built using the Sancta Via ecosystem packages hosted on GitHub:

- [`sancta_via_saint_data`](https://github.com/superversivesf/sancta_via_saint_data) - Saint dataset, SQLite store, and search
- [`sancta_via_liturgical_calendar`](https://github.com/superversivesf/sancta_via_liturgical_calendar) - Core liturgical calendar engine
- [`sancta_via_liturgical_calendar_riverpod`](https://github.com/superversivesf/sancta_via_liturgical_calendar_riverpod) - Reactive state management
- [`sancta_via_shared_ui`](https://github.com/superversivesf/sancta_via_shared_ui) - Shared UI components and theming
- Flutter with Material 3 design

## 🛠️ Development

This project uses the `melos` monorepo tooling. From the repository root:

```sh
dart run melos bootstrap
```

Build commands are available via `make` (see the `Makefile`):

```sh
make deps        # Install dependencies
make test        # Run tests
make analyze     # Static analysis
make format      # Format code
make build-android
make build-ios
```
