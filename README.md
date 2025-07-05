# Sancta Via Prayer Companion

A Catholic prayer companion app built with Flutter, featuring an extensive collection of traditional prayers and devotions. This standalone app integrates with the Sancta Via ecosystem's liturgical calendar and provides modern prayer management features.

## Features

### 🎨 **Liturgical Theming**
- Dynamic theming based on current liturgical season
- Vibrant and muted color intensity options
- Seamless integration with liturgical calendar

### 🙏 **Prayer Management**
- Comprehensive prayer library with 60+ traditional Catholic prayers
- Prayer categories and organizational structure
- Favorites and recent prayers tracking
- Search and filtering capabilities

### ⭐ **Prayer of the Day**
- Intelligent prayer selection based on liturgical season
- Special prayers for feast days and solemnities
- Contextual recommendations with liturgical reasoning

### 📱 **Modern UI**
- Material Design 3 with liturgical color accents
- Responsive layouts supporting mobile, tablet, and desktop
- Accessible UI with dark/light theme support and text scaling

## Prayer Collection

The app includes traditional Catholic prayers organized by categories:

### **Core Prayers**
- Our Father, Hail Mary, Glory Be
- Apostles' Creed, Act of Contrition
- Angelus, Anima Christi

### **Daily Prayers**  
- Morning Offering, Bedtime prayers
- Examination of conscience

### **Marian Prayers**
- Hail Mary, Regina Caeli
- Various Marian devotions

### **Prayers to Saints**
- Prayer to St. Michael, Guardian Angel Prayer
- Saints intercessions and devotions

### **Liturgical Prayers**
- Veni Creator Spiritus
- Seasonal and liturgical devotions

## Dependencies

This app is part of the Sancta Via ecosystem and depends on several shared packages:

- [`sancta_via_shared_ui`](https://github.com/superversivesf/sancta_via_shared_ui) - Shared UI components with liturgical theming
- [`sancta_via_liturgical_calendar`](https://github.com/superversivesf/sancta_via_liturgical_calendar) - Catholic liturgical calendar data
- [`sancta_via_liturgical_calendar_riverpod`](https://github.com/superversivesf/sancta_via_liturgical_calendar_riverpod) - Riverpod providers for liturgical calendar

## Architecture

### **Core Components**
- **Repository Layer**: `PrayerRepository` for data access
- **Service Layer**: Prayer management and liturgical integration
- **Provider Layer**: Riverpod providers for state management
- **UI Layer**: Screens and widgets with liturgical theming

### **Data Structure**
```
assets/prayers/
├── prayers_metadata.json  # Categories, groups, and prayer metadata
└── [prayer_id].json       # Individual prayer files with translations
```

## Getting Started

### Prerequisites

- Flutter SDK (3.8.1 or higher)
- Dart SDK (3.8.1 or higher)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/superversivesf/sancta_via_prayer_companion.git
   cd sancta_via_prayer_companion
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
├── models/           # Prayer data models and categories
├── providers/        # Global app state providers
├── repositories/     # Prayer data repository
├── screens/          # Main app screens
│   ├── categories/   # Prayer category browsing
│   ├── home/         # Home screen
│   ├── prayer/       # Prayer detail and list screens
│   ├── search/       # Prayer search functionality
│   └── settings/     # App settings
└── utils/            # Utility functions and helpers
```

## Development

### Adding New Prayers
1. Add prayer metadata to `assets/prayers/prayers_metadata.json`
2. Create prayer file `assets/prayers/[prayer_id].json`
3. Include translations and attribution as needed

### Extending Functionality
- The app uses liturgical providers for calendar integration
- Theme components are shared via the `sancta_via_shared_ui` package
- Prayer providers can be extended for additional features

## Integration with Sancta Via Ecosystem

This app demonstrates:
- **Code Reuse**: Shared UI components across apps
- **Consistency**: Unified theming and liturgical integration  
- **Maintainability**: Single source of truth for liturgical data
- **Scalability**: Easy to add new apps using the same foundation

## Contributing

This project follows the Sancta Via development guidelines. Please ensure all code:

- Follows Flutter/Dart conventions
- Includes appropriate tests
- Maintains accessibility standards
- Respects liturgical accuracy and Catholic teaching

## License

This project is part of the Sancta Via Catholic app ecosystem.

## Support

For support or questions about this app, please visit [Sancta Via](https://sancta-via.net).