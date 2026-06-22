import 'dart:convert';
import 'dart:typed_data';

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
      // The `flutter/assets` channel used by `rootBundle.loadString` is a raw
      // binary message channel (StandardMessageCodec is NOT used). The outbound
      // message is the URL-encoded asset path as UTF-8 bytes, and the reply is
      // the raw asset content as bytes. Using `setMockMethodCallHandler` wraps
      // messages with a MethodCodec envelope, which causes a
      // `FormatException: Message corrupted` when `rootBundle` decodes the
      // reply. Instead we register a raw message handler on the channel.
      const String cpdvJson = '''
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

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
        if (message == null) {
          return null;
        }
        // The outgoing message is the URL-encoded asset path as UTF-8 bytes.
        final String assetPath = utf8.decode(
          Uint8List.sublistView(message),
        );

        if (assetPath.contains('cpdv.json')) {
          final Uint8List replyBytes = Uint8List.fromList(
            utf8.encode(cpdvJson),
          );
          return ByteData.sublistView(replyBytes);
        }
        // Asset not found: return null so rootBundle raises the expected error.
        return null;
      });

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
      final content = await service.getScriptureByReference(
        'Mark 1:1',
        BibleTranslation.cpdv,
      );

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
