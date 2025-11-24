# Sancta Via Confession Companion

A Catholic examination of conscience and confession companion app built with Flutter. This app helps Catholics prepare for the Sacrament of Confession through guided examinations of conscience.

## Features

- **Guided Examinations of Conscience**: Multiple examination types for different needs and spiritual levels
- **Liturgical Calendar Integration**: App theming that reflects the current liturgical season and colors
- **Session Tracking**: Keep track of completed examinations and confession preparations
- **Responsive Design**: Works across mobile, tablet, and desktop platforms
- **Accessible UI**: Dark/light theme support with adjustable text scaling

## Dependencies

This app is part of the Sancta Via ecosystem and depends on several shared packages:

- [`sancta_via_shared_ui`](https://github.com/superversivesf/sancta_via_shared_ui) - Shared UI components with liturgical theming
- [`sancta_via_liturgical_calendar`](https://github.com/superversivesf/sancta_via_liturgical_calendar) - Catholic liturgical calendar data
- [`sancta_via_liturgical_calendar_riverpod`](https://github.com/superversivesf/sancta_via_liturgical_calendar_riverpod) - Riverpod providers for liturgical calendar

## Getting Started

### Prerequisites

- Flutter SDK (3.8.1 or higher)
- Dart SDK (3.8.1 or higher)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/superversivesf/sancta_via_confession_companion.git
   cd sancta_via_confession_companion
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

### Building for Production

#### Android
```bash
flutter build apk --release
```

#### iOS
```bash
flutter build ios --release
```

#### Web
```bash
flutter build web --release
```

## Project Structure

```
lib/
├── config/           # App configuration and constants
├── features/         # Feature-based modules
│   └── examination/  # Examination of conscience features
├── providers/        # Global app state providers
└── screens/          # Main app screens
```

## Contributing

This project follows the Sancta Via development guidelines. Please ensure all code:

- Follows Flutter/Dart conventions
- Includes appropriate tests
- Maintains accessibility standards
- Respects liturgical accuracy

## License

This project is part of the Sancta Via Catholic app ecosystem.

## Support

For support or questions about this app, please visit [Sancta Via](https://sancta-via.net).
