# Bible Data Package

A pure Dart package for Catholic Bible texts with search and lookup capabilities.

## Features

- **Multiple Bible Translations**: Support for Catholic Public Domain Version (CPDV), Douay-Rheims (DRC), and World English Bible Catholic (WEB-C)
- **Fast Lookups**: Efficient book, chapter, and verse retrieval
- **Full-Text Search**: Search across all books with relevance scoring
- **Scripture References**: Parse and validate scripture references in various formats
- **Book Mapping**: Standardized book name, ID, and abbreviation mapping
- **Memory Efficient**: Lazy loading and caching for optimal performance
- **Pure Dart**: No dependencies on Flutter or external services

## Usage

### Basic Scripture Lookup

```dart
import 'package:bible_data/bible_data.dart';

// Create a Bible service with your preferred loader
final loader = EmbeddedBibleLoader(); // or AssetBibleLoader, NetworkBibleLoader
final service = BibleService(loader);

// Get scripture content
final content = await service.getScriptureByReference(
  'John 3:16', 
  BibleTranslation.cpdv
);

if (content.found) {
  print(content.text);
} else {
  print('Scripture not found: ${content.errorMessage}');
}
```

### Scripture References

```dart
// Parse references in various formats
final ref1 = ScriptureReference.parse('Genesis 1:1');
final ref2 = ScriptureReference.parse('1 Corinthians 13:4-8');
final ref3 = ScriptureReference.parse('Psalm 23');

// Create references programmatically
final verseRef = ScriptureReference.verse('Matthew', 5, 3);
final rangeRef = ScriptureReference.range('Romans', 8, 28, 30);
final chapterRef = ScriptureReference.chapter('John', 1);

// Check reference properties
print(ref1.isSingleVerse); // true
print(ref2.isVerseRange); // true
print(ref3.isEntireChapter); // true
```

### Searching Scripture

```dart
// Basic text search
final results = await service.searchText(
  'love', 
  BibleTranslation.cpdv,
  maxResults: 10
);

for (final result in results) {
  print('${result.reference.displayText} - ${result.verse.text}');
}

// Advanced search options
final filtered = await service.searchText(
  'peace',
  BibleTranslation.cpdv,
  caseSensitive: false,
  wholeWords: true,
  newTestamentOnly: true,
  maxResults: 5
);

// Search for specific verse numbers
final searchService = await service.getSearchService(BibleTranslation.cpdv);
final verse16s = await searchService.searchByVerseNumber(16);
```

### Book Mapping

```dart
// Find books by various identifiers
final genesis = BibleBookMapping.getByName('Genesis');
final matthew = BibleBookMapping.getById('mat');
final psalms = BibleBookMapping.getByAbbreviation('Ps');

// Universal book finder
final found = BibleBookMapping.findBook('1 John'); // Works with name, ID, or abbreviation

// Get book collections
final otBooks = BibleBookMapping.oldTestamentBooks;
final ntBooks = BibleBookMapping.newTestamentBooks;
final allBooks = BibleBookMapping.allBooks;
```

### Bible Loaders

The package supports different loading strategies:

#### Embedded Loader (Recommended)
```dart
// Initialize once with your Bible JSON data
EmbeddedBibleLoader.initialize({
  BibleTranslation.cpdv: cpdvJsonString,
  BibleTranslation.drc: drcJsonString,
  // ...
});

final loader = EmbeddedBibleLoader();
```

#### Asset Loader (Flutter Apps)
```dart
import 'package:flutter/services.dart';

final loader = AssetBibleLoader(
  assetBasePath: 'assets/bibles',
  assetLoader: rootBundle.loadString,
);
```

#### Network Loader
```dart
import 'package:http/http.dart' as http;

final loader = NetworkBibleLoader(
  baseUrl: 'https://api.example.com/bibles',
  httpClient: (url) async => (await http.get(Uri.parse(url))).body,
);
```

## Supported Bible Formats

The package expects Bible data in the following JSON format:

```json
{
  "translation": "Catholic Public Domain Version",
  "metadata": {
    "name": "Catholic Public Domain Version",
    "abbreviation": "CPDV",
    "books": 73,
    "verses": 31102
  },
  "books": [
    {
      "name": "Genesis",
      "chapters": [
        {
          "chapter": 1,
          "verses": [
            {
              "verse": 1,
              "text": "In the beginning, God created heaven and earth."
            }
          ]
        }
      ]
    }
  ]
}
```

## Performance Tips

1. **Preload Translations**: Load commonly used translations at app startup
```dart
await service.preloadTranslations([BibleTranslation.cpdv]);
```

2. **Use Caching**: The service automatically caches loaded Bibles and search services

3. **Clear Cache**: Clear caches when memory is needed
```dart
service.clearCache();
```

4. **Batch Operations**: Use `getMultipleScriptures()` for multiple lookups

## Book Identification

The package uses standardized book IDs and supports various input formats:

- **Full Names**: "Genesis", "1 Corinthians", "Revelation" 
- **Abbreviations**: "Gen", "1 Cor", "Rev"
- **Book IDs**: "gen", "1co", "rev"
- **Roman Numerals**: "I Corinthians" → "1 Corinthians"

## Error Handling

All operations return structured results that indicate success or failure:

```dart
final content = await service.getScriptureContent(reference, translation);
if (!content.found) {
  print('Error: ${content.errorMessage}');
  // Handle gracefully - perhaps show fallback content
}
```

## Thread Safety

The package is designed to be thread-safe with immutable data models and proper caching mechanisms.

## Contributing

This package is part of the Sancta Via ecosystem. See the main repository for contribution guidelines.

## License

MIT License - see the LICENSE file for details.
