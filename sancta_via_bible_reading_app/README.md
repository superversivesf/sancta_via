# Sancta Via Bible Reading App

A Catholic Bible reading app built with Flutter, featuring multiple traditional Catholic Bible translations with liturgical integration and modern reading features. This app provides Catholics with a comprehensive Scripture reading experience aligned with Church teachings.

## Features

### 📖 **Catholic Bible Translations**
- **Catholic Public Domain Version (CPDV)** - Modern Catholic translation in public domain
- **Douay-Rheims Catholic Bible (DRC)** - Traditional Catholic translation from the Vulgate
- **English Web Bible Catholic (engwebc)** - Catholic edition with deuterocanonical books

### 🎨 **Liturgical Integration**
- **Dynamic Theming** - App colors reflect current liturgical season
- **Calendar Alignment** - Reading experience adapted to Church calendar
- **Seasonal Colors** - UI reflects liturgical celebrations and seasons
- **Color Intensity Options** - Customize liturgical color vibrancy

### 📱 **Modern Reading Experience**
- **Chapter Reading Interface** - Dedicated, distraction-free reading screen
- **Progress Scroll Bar** - Elegant, thin scroll indicator showing reading progress
- **Book Navigation** - Easy browsing and selection of Bible books
- **Text Scaling** - Adjustable font sizes for accessibility
- **Responsive Design** - Optimized for mobile, tablet, and desktop
- **Dark/Light Themes** - Full theme customization options
- **Settings Management** - Personalized reading preferences

### 🔍 **Advanced Bible Features**
- **Multiple Translation Support** - Switch between Catholic translations
- **Search Capabilities** - Find verses and passages across translations
- **Reading Progress Tracking** - Visual scroll bar shows chapter progress
- **Bookmark System** - Save important passages for reference
- **Cross-References** - Navigate related Scripture passages
- **Chapter Navigation** - Swipe between chapters with floating action buttons

## Dependencies

This app is part of the Sancta Via ecosystem and depends on several shared packages:

- [`sancta_via_shared_ui`](https://github.com/superversivesf/sancta_via_shared_ui) - Shared UI components with liturgical theming
- [`sancta_via_liturgical_calendar`](https://github.com/superversivesf/sancta_via_liturgical_calendar) - Catholic liturgical calendar data
- [`sancta_via_liturgical_calendar_riverpod`](https://github.com/superversivesf/sancta_via_liturgical_calendar_riverpod) - Riverpod providers for liturgical calendar
- [`sancta_via_bible_data`](https://github.com/superversivesf/sancta_via_bible_data) - Catholic Bible text data and search capabilities
- [`sancta_via_bible_data_riverpod`](https://github.com/superversivesf/sancta_via_bible_data_riverpod) - Riverpod providers for Bible data

## Architecture

### **Core Components**
- **Optimized Bible Data Engine** - Chapter-level caching for instant Scripture access
- **Reading Interface** - Optimized chapter reading with liturgical theming and progress indication
- **Navigation System** - Intuitive book and chapter browsing
- **Settings Management** - Comprehensive user preference system  
- **State Management** - Reactive Bible reading state with Riverpod
- **Performance System** - Persistent SQLite database with smart caching

### **🔧 Technical Optimizations**
- **OptimizedSqliteBibleLoader**: Loads individual chapters instead of entire Bibles
- **Chapter-Level Providers**: Fast providers that query specific content only
- **LRU Cache**: Recently accessed chapters cached in memory (max 50 chapters)
- **Database Persistence**: SQLite database copied once, used persistently
- **Fast Startup**: No expensive operations during app initialization
- **Memory Efficiency**: 96% reduction in memory usage vs full Bible loading

### **Data Structure**
```
assets/
├── bibles.db           # Pre-built SQLite database for fast access
└── app_icon.png        # Application icon

dev_resources/          # Development-only resources (NOT shipped)
└── bibles/             # Bible translation files (compressed)
    ├── cpdv.json.gz    # Catholic Public Domain Version (compressed)
    ├── drc.json.gz     # Douay-Rheims Catholic Bible (compressed)
    └── engwebc.json.gz # English Web Bible Catholic (compressed)
```

### **Compression & Performance**
- **Development-Only Compression**: JSON files are gzipped for version control (~82% space savings)
- **App Bundle Optimization**: Only SQLite database shipped (~5.5MB reduction in app size)
- **Runtime Performance**: Uses SQLite database for fast Bible access
- **No Runtime Decompression**: App startup consistently fast (no JSON processing)

### **⚡ Performance Optimizations**
- **Fast App Startup**: Optimized Bible service loads instantly (no full Bible loading)
- **Chapter-Level Caching**: Only loads specific chapters as needed (96% memory savings)
- **Persistent Database**: SQLite database persists between app restarts
- **No Repeated Loading**: After initial setup, app startup is consistently fast
- **Memory Efficient**: ~500KB cache vs ~12MB for full Bible loading
- **Reading Progress**: Elegant scroll bar shows chapter progress without performance impact

### **Bible Translation Details**

#### **Catholic Public Domain Version (CPDV)**
- Modern English translation
- Public domain status
- Clear, accessible language
- Full Catholic canon including deuterocanonical books

#### **Douay-Rheims Catholic Bible (DRC)**
- Traditional Catholic translation
- Based on the Latin Vulgate
- Historical significance in English Catholicism
- Traditional language and phrasing

#### **English Web Bible Catholic (engwebc)**
- Contemporary Catholic edition
- Includes deuterocanonical books
- Modern language with Catholic distinctives

## Getting Started

### Prerequisites

- Flutter SDK (3.8.1 or higher)
- Dart SDK (3.8.1 or higher)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/superversivesf/sancta_via_bible_reading_app.git
   cd sancta_via_bible_reading_app
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

#### Compress Bible Data (development only)
```bash
# Compress JSON files for version control (development only)
./scripts/compress_bibles.sh

# Decompress a file for editing (stored in dev_resources/bibles/)
./scripts/compress_bibles.sh decompress cpdv.json.gz
```

**Note**: Compressed files in `dev_resources/bibles/` are for development only and are NOT shipped with the app.

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
├── models/           # App data models and settings
├── providers/        # Global app state providers
├── screens/          # Main app screens
│   ├── chapter/      # Bible chapter reading interface
│   ├── home/         # Home screen and navigation
│   └── settings/     # App settings and preferences
└── main.dart         # Application entry point
```

## Reading Features

The app provides a comprehensive Bible reading experience:

- **Intuitive Navigation** - Easy access to all 73 books of the Catholic Bible
- **Multiple Translations** - Compare passages across different Catholic versions
- **Liturgical Context** - Reading experience enhanced by liturgical awareness
- **Accessibility** - Font scaling and theme options for all users
- **Cross-Platform** - Consistent experience across devices

## Integration with Sancta Via Ecosystem

This app demonstrates:
- **Bible Data Integration** - Sophisticated Scripture access and search
- **Liturgical Awareness** - Reading experience aligned with Church calendar
- **Shared UI Components** - Consistent design across Catholic apps
- **Cross-Platform Excellence** - Quality experience on all devices
- **Catholic Authenticity** - Faithful to Catholic teaching and tradition

## Development

### Adding New Bible Translations
1. Prepare translation data in the required JSON format
2. Add translation file to `assets/bibles/`
3. Update app constants and providers
4. Test thoroughly for accuracy and completeness

### Extending Reading Features
- The app uses Bible data providers for Scripture access
- Reading interface can be enhanced with additional features
- Liturgical integration provides contextual reading experiences

## Contributing

This project follows the Sancta Via development guidelines. Please ensure all code:

- Follows Flutter/Dart conventions
- Includes appropriate tests
- Maintains accessibility standards
- Respects liturgical accuracy and Catholic teaching
- Handles Bible text with appropriate reverence

## License

This project is part of the Sancta Via Catholic app ecosystem.

## Support

For support or questions about this app, please visit [Sancta Via](https://sancta-via.net).