# Bible Data Files

This package includes sample Bible data for testing and development. For production use, you'll need the complete Bible translations.

## Sample Data

The `assets/bibles/sample_cpdv.json` file contains a small subset of the Catholic Public Domain Version Bible with:
- Genesis 1:1-3
- John 3:16-17
- Psalm 23:1-4

This is sufficient for testing the package functionality and understanding the data format.

## Full Bible Data

The complete Bible translations are available in the legacy directory of this repository:

### Available Translations

1. **Catholic Public Domain Version (CPDV)**
   - File: `legacy/assets/readings/bibles/cpdv.json`
   - Size: ~10.6 MB
   - 73 books, 31,102 verses

2. **Douay-Rheims Catholic (DRC)**
   - File: `legacy/assets/readings/bibles/drc.json`
   - Size: ~10.3 MB
   - Traditional Catholic translation

3. **World English Bible Catholic (WEB-C)**
   - File: `legacy/assets/readings/bibles/engwebc.json`
   - Size: ~10.3 MB
   - Modern English with Catholic book order

### Using Full Data

To use the complete Bible data in your application:

#### Option 1: Copy Files (Flutter Apps)
```bash
# Copy the files to your app's assets directory
cp legacy/assets/readings/bibles/*.json your_app/assets/bibles/

# Update your pubspec.yaml
flutter:
  assets:
    - assets/bibles/
```

Then use the AssetBibleLoader:
```dart
import 'package:flutter/services.dart';
import 'package:bible_data/bible_data.dart';

final loader = AssetBibleLoader(
  assetBasePath: 'assets/bibles',
  assetLoader: rootBundle.loadString,
);
final service = BibleService(loader);
```

#### Option 2: Embed Data (Any Dart App)
```dart
import 'dart:io';
import 'package:bible_data/bible_data.dart';

// Load the JSON strings
final cpdvJson = await File('legacy/assets/readings/bibles/cpdv.json').readAsString();
final drcJson = await File('legacy/assets/readings/bibles/drc.json').readAsString();
final webJson = await File('legacy/assets/readings/bibles/engwebc.json').readAsString();

// Initialize the embedded loader
EmbeddedBibleLoader.initialize({
  BibleTranslation.cpdv: cpdvJson,
  BibleTranslation.drc: drcJson,
  BibleTranslation.engwebc: webJson,
});

final loader = EmbeddedBibleLoader();
final service = BibleService(loader);
```

#### Option 3: Network Loading
Host the JSON files on a server and use NetworkBibleLoader:
```dart
final loader = NetworkBibleLoader(
  baseUrl: 'https://your-server.com/bibles',
  httpClient: (url) async => (await http.get(Uri.parse(url))).body,
);
```

## Data Format

All Bible files follow this JSON structure:

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

## Performance Considerations

- **File Size**: Each complete Bible is ~10MB. Consider lazy loading for mobile apps.
- **Memory Usage**: The EmbeddedBibleLoader keeps data in memory. Use AssetBibleLoader for better memory management.
- **Caching**: All loaders include caching to avoid repeated parsing.

## License

The Bible texts are in the public domain. The specific translations used are:

- **CPDV**: Public domain translation from the Latin Vulgate
- **DRC**: Public domain, original Douay-Rheims translation
- **WEB-C**: Public domain World English Bible with Catholic book order

See individual files for detailed attribution information.
