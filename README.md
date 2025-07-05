# Sancta Via Novena Companion

A Catholic novena companion app built with Flutter, featuring traditional nine-day prayer devotions with advanced notification scheduling, progress tracking, and liturgical integration. This sophisticated app helps Catholics participate in novenas with proper spiritual preparation and daily reminders.

## Features

### 📿 **Traditional Novena Collection**
- **Divine Mercy Novena** - The famous novena revealed to St. Faustina
- **Sacred Heart of Jesus** - Nine-day devotion to the Sacred Heart
- **Immaculate Heart of Mary** - Marian devotion for spiritual preparation
- **St. Jude Novena** - Patron saint of impossible causes
- **St. Joseph Novena** - Foster father of Jesus and patron of workers
- **St. Anthony Novena** - Beloved saint for lost things and miracles
- **St. Thérèse (Little Flower)** - The way of spiritual childhood
- **St. John Paul II** - Modern saint and spiritual guide
- **Our Lady of Perpetual Help** - Traditional Marian devotion

### 🔔 **Advanced Notification System**
- **Daily Prayer Reminders** - Customizable notification times for each day
- **Progress Notifications** - Track completion and encourage consistency
- **Follow-up Reminders** - Gentle prompts for missed prayers
- **Completion Celebrations** - Acknowledgment when novena is finished
- **Timezone Support** - Accurate scheduling across time zones

### 🔐 **Security & Privacy**
- **PIN Authentication** - Optional PIN protection for personal devotions
- **Secure Storage** - Encrypted storage for sensitive prayer data
- **Privacy Controls** - Full control over data and notification preferences
- **Fresh Installation Detection** - Clean setup for new installations

### 📊 **Progress Tracking**
- **Daily Completion Status** - Visual tracking of prayer completion
- **Novena History** - Record of completed novenas
- **Streak Tracking** - Maintain consistent prayer habits
- **Personal Reflection** - Space for spiritual notes and intentions

### 🎨 **Liturgical Integration**
- **Dynamic Theming** - App colors reflect current liturgical season
- **Calendar Integration** - Novenas aligned with liturgical calendar
- **Seasonal Adaptation** - UI adapts to Church calendar celebrations
- **Color Intensity Options** - Customize liturgical color vibrancy

### 📱 **Modern User Experience**
- **Material Design 3** - Contemporary, accessible interface
- **Custom Fonts** - Google Fonts for enhanced readability
- **Responsive Design** - Works across mobile, tablet, and desktop
- **Auto-sizing Text** - Adaptive text for different screen sizes
- **Dark/Light Themes** - Full theme customization
- **Font Scaling** - Adjustable text size for accessibility

## Dependencies

This app is part of the Sancta Via ecosystem and depends on several shared packages:

- [`sancta_via_shared_ui`](https://github.com/superversivesf/sancta_via_shared_ui) - Shared UI components with liturgical theming
- [`sancta_via_liturgical_calendar`](https://github.com/superversivesf/sancta_via_liturgical_calendar) - Catholic liturgical calendar data
- [`sancta_via_liturgical_calendar_riverpod`](https://github.com/superversivesf/sancta_via_liturgical_calendar_riverpod) - Riverpod providers for liturgical calendar

## Architecture

### **Advanced Features**
- **Go Router Navigation** - Modern, declarative routing system
- **Riverpod State Management** - Reactive state management throughout
- **Secure Storage Service** - Encrypted data persistence
- **Notification Service** - Comprehensive notification management
- **App Lifecycle Management** - Handle date changes and app states
- **Permission Management** - Smart permission requests and handling

### **Core Components**
- **Authentication System** - PIN-based security for personal devotions
- **Novena Engine** - Core logic for novena progression and timing
- **Notification Scheduler** - Advanced notification scheduling with timezone support
- **Progress Tracker** - Detailed completion and streak tracking
- **Settings Management** - Comprehensive user preference system

### **Data Structure**
```
assets/
├── novenas/           # Individual novena JSON files
├── prayers/           # Supporting prayers and texts
├── images/            # Visual assets and icons
└── icons/             # Custom iconography
```

## Getting Started

### Prerequisites

- Flutter SDK (3.8.1 or higher)
- Dart SDK (3.8.1 or higher)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/superversivesf/sancta_via_novena_companion.git
   cd sancta_via_novena_companion
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
├── config/           # App configuration, routes, and constants
├── features/         # Feature-based modules
│   ├── auth/         # PIN authentication system
│   ├── home/         # Home screen and dashboard
│   ├── novenas/      # Novena core functionality
│   └── settings/     # App settings and preferences
├── providers/        # Global app state providers
├── services/         # Core services (notifications, storage, etc.)
└── utils/            # Utility functions and helpers
```

## Novena Collection

Each novena includes:

- **Complete Prayer Texts** - All daily prayers and intentions
- **Historical Context** - Background on the devotion's origins
- **Spiritual Guidance** - Tips for meaningful participation
- **Liturgical Connections** - How the novena relates to Church calendar
- **Personal Intentions** - Space for individual prayer requests

## Notification Features

The app includes sophisticated notification management:

- **Smart Scheduling** - Notifications adapt to user patterns
- **Graceful Degradation** - Works even when permissions are limited
- **Cross-Platform Support** - Consistent experience across devices
- **Timezone Awareness** - Accurate timing regardless of location
- **Customizable Timing** - Full control over when reminders appear

## Development

### Adding New Novenas
1. Create novena JSON file in `assets/novenas/`
2. Update metadata in `novenas_metadata.json`
3. Add any supporting prayers or images
4. Update app constants if needed

### Extending Functionality
- The app uses Go Router for navigation management
- Riverpod providers handle all state management
- Secure storage encrypts sensitive user data
- Notification service provides comprehensive reminder system

## Integration with Sancta Via Ecosystem

This app demonstrates advanced features:
- **Complex State Management** - Multi-feature app with sophisticated state
- **Security Integration** - PIN protection and secure storage
- **Notification Systems** - Advanced scheduling and reminder management
- **Liturgical Theming** - Deep integration with Church calendar
- **Cross-Platform Excellence** - Consistent experience across all devices

## Contributing

This project follows the Sancta Via development guidelines. Please ensure all code:

- Follows Flutter/Dart conventions
- Includes appropriate tests
- Maintains accessibility standards
- Respects liturgical accuracy and Catholic teaching
- Handles user privacy and security appropriately

## License

This project is part of the Sancta Via Catholic app ecosystem.

## Support

For support or questions about this app, please visit [Sancta Via](https://sancta-via.net).