# Sancta Via Fasting Companion

A Catholic fasting companion app that tracks various fasting types (intermittent, 24-hour, multi-day) with integrated encouragement featuring scriptural quotes, saint writings, prayers, and imagery to support spiritual growth through fasting.

## Features (Planned)

- **Fasting Tracker**: Track intermittent, 24-hour, and multi-day fasts
- **Encouragement System**: Scriptural quotes, saint writings, and prayers during fasts
- **Liturgical Integration**: Dynamic theming based on the Catholic liturgical calendar
- **Notifications**: Customizable reminders and milestone celebrations
- **History & Statistics**: Track your fasting journey over time

## Getting Started

### Prerequisites

- Flutter SDK (>=3.9.2)
- Dart SDK
- iOS/Android development environment or web browser

### Installation

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Build Commands

See `Makefile` for available commands:

```bash
make deps              # Install dependencies
make clean             # Clean build files
make format            # Format code
make analyze           # Run static analysis
make test              # Run tests
make build-android     # Build Android APK
make build-ios         # Build iOS app
make build-web         # Build web app
```

## Project Structure

```
lib/
├── main.dart                    # Entry point with ProviderScope
├── config/
│   └── routes.dart             # GoRouter configuration
├── database/                    # SQLite schema and queries
├── models/                      # Data models
├── providers/                   # Riverpod state management
├── repositories/                # Data access layer
├── screens/                     # UI screens
│   ├── home/
│   └── settings/
├── services/                    # Business logic
└── widgets/                     # Reusable widgets
```

## Architecture

This app follows the standard SanctaVia architecture:

1. **Model Layer** - Data structures
2. **Database Layer** - SQLite persistence
3. **Repository Layer** - Single source of truth with caching
4. **Service Layer** - Business logic
5. **Provider Layer** - Riverpod state management
6. **UI Layer** - Screens and widgets

## Dependencies

- **flutter_riverpod** - State management
- **go_router** - Navigation
- **sqflite** - Local database
- **flutter_local_notifications** - Push notifications
- **sancta_via_shared_ui** - Shared UI components
- **sancta_via_liturgical_calendar** - Liturgical calendar data
- **sancta_via_liturgical_calendar_riverpod** - Liturgical calendar providers

## Development Status

🚧 **Under Development** - Initial project setup complete

## License

Copyright © 2024 Sancta Via. All rights reserved.
