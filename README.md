# Bible Data Riverpod

Riverpod providers for the `bible_data` package with reactive state management, automatic caching, and Flutter integration.

[![Pub Package](https://img.shields.io/pub/v/bible_data_riverpod.svg)](https://pub.dev/packages/bible_data_riverpod)
[![Flutter](https://img.shields.io/badge/Flutter-3.7.2+-blue.svg)](https://flutter.dev)

## 🚀 **Reactive Bible Access**

This package provides Flutter Riverpod integration for the `bible_data` package, offering:

- ⚡ **Reactive state management** - Automatic UI updates when data changes
- 🔄 **Smart caching** - Efficient memory management and performance
- 🎛️ **User preferences** - Bible translation, reading settings, favorites
- 🔍 **Advanced search** - Full-text search with history and suggestions
- 📖 **Scripture management** - Current reading, favorites, history

## 📦 **Installation**

Add to your `pubspec.yaml`:

```yaml
dependencies:
  bible_data_riverpod: ^1.0.0
  flutter_riverpod: ^2.6.1
```

## 🎯 **Quick Start**

### 1. Setup ProviderScope

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}
```

### 2. Basic Scripture Reading

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bible_data_riverpod/bible_data_riverpod.dart';

class ScriptureWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scripture = ref.watch(scriptureProvider('John 3:16'));
    
    return scripture.when(
      data: (content) => Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content.reference.displayText,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: 8),
              Text(content.text),
            ],
          ),
        ),
      ),
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => Text('Error: $error'),
    );
  }
}
```

## 🏗️ **Available Providers**

### Core Providers
- `bibleServiceProvider` - Main Bible service instance
- `bibleServiceNotifierProvider` - Service with initialization state
- `availableTranslationsProvider` - List of available Bible translations
- `bibleStatsProvider` - Bible statistics and cache info

### Scripture Providers
- `scriptureProvider(reference)` - Get scripture by reference string
- `scriptureByReferenceProvider(params)` - Get scripture by parsed reference
- `multipleScripturesProvider(params)` - Get multiple scriptures at once
- `currentScriptureProvider` - Manage current reading state
- `todaysScriptureProvider` - Suggested daily scripture

### Search Providers
- `scriptureSearchProvider(query)` - Search scripture text
- `searchStateProvider` - Manage search state and history
- `searchSuggestionsProvider` - Popular search suggestions
- `searchHistoryProvider` - Search history management
- `verseNumberSearchProvider(number)` - Search by verse number

### Settings Providers
- `selectedBibleTranslationProvider` - Currently selected translation
- `bibleReadingPreferencesProvider` - Reading preferences (font, display)
- `searchSettingsProvider` - Search configuration
- `favoriteScripturesProvider` - Favorite scripture references

## 📖 **Complete Documentation**

For complete usage examples, advanced features, and integration guides, see the full documentation in the package repository.

## 📄 **License**

MIT License - see the LICENSE file for details.

---

**Bringing Catholic Scripture to Flutter with reactive state management.** 📖✨
