import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:bible_data/bible_data.dart';

void main() {
  // Initialize Flutter test binding
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bible Data Loading Tests', () {
    late AssetBibleLoader loader;
    late BibleService service;

    setUpAll(() {
      // Mock asset loading for testing
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter/assets'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'loadString') {
            final String assetPath = methodCall.arguments as String;
            
            // Return test data for our Bible assets
            if (assetPath.contains('cpdv.json')) {
              return '''
{
  "translation": "cpdv",
  "metadata": {
    "name": "Catholic Public Domain Version",
    "abbreviation": "CPDV",
    "language": "en"
  },
  "books": [
    {
      "name": "Mark",
      "chapters": [
        {
          "number": 1,
          "verses": [
            {
              "number": 1,
              "text": "The beginning of the Gospel of Jesus Christ, the Son of God."
            },
            {
              "number": 2,
              "text": "As it has been written by the prophet Isaiah: \\"Behold, I send my Angel before your face, who shall prepare your way before you.\\""
            }
          ]
        }
      ]
    }
  ]
}
''';
            }
            throw PlatformException(code: 'asset_not_found', message: 'Asset not found: $assetPath');
          }
          return null;
        },
      );

      loader = AssetBibleLoader(
        assetBasePath: 'assets/bibles',
        assetLoader: rootBundle.loadString,
      );
      service = BibleService(loader);
    });

    test('should load CPDV Bible successfully', () async {
      final bible = await service.getBible(BibleTranslation.cpdv);
      
      expect(bible.translation, BibleTranslation.cpdv);
      expect(bible.books.length, 1);
      expect(bible.books.first.name, 'Mark');
    });

    test('should parse Mark 1:1 reference', () {
      final reference = ScriptureReference.parse('Mark 1:1');
      
      expect(reference.book, 'Mark');
      expect(reference.chapter, 1);
      expect(reference.startVerse, 1);
      expect(reference.endVerse, 1);
    });

    test('should get Mark 1:1 scripture content', () async {
      final content = await service.getScriptureByReference('Mark 1:1', BibleTranslation.cpdv);
      
      expect(content.found, true);
      expect(content.text, contains('beginning of the Gospel'));
      expect(content.translation, BibleTranslation.cpdv);
    });

    test('should parse Mark 1:1-8 range reference', () {
      final reference = ScriptureReference.parse('Mark 1:1-8');
      
      expect(reference.book, 'Mark');
      expect(reference.chapter, 1);
      expect(reference.startVerse, 1);
      expect(reference.endVerse, 8);
      expect(reference.isVerseRange, true);
    });
  });
}
