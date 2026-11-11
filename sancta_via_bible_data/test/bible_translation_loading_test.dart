import 'dart:convert';
import 'dart:io';

import 'package:bible_data/src/models/bible.dart';
import 'package:bible_data/src/models/bible_translation.dart';
import 'package:test/test.dart';

/// `Bible.fromJson` must map the rebuilt `assets/bibles/*.json` assets to the
/// right [BibleTranslation] enum value. The rebuilt drc asset carries the
/// names `Douay-Rheims 1899 American Edition (Challoner)` / `DRA`, which the
/// loader previously did not recognize (falling through to the cpdv default).
const Map<String, BibleTranslation> _expected = <String, BibleTranslation>{
  'engwebc': BibleTranslation.engwebc,
  'cpdv': BibleTranslation.cpdv,
  'drc': BibleTranslation.drc,
};

Map<String, dynamic> _asset(String id) {
  final File file = File('assets/bibles/$id.json');
  if (!file.existsSync()) {
    fail('missing rebuilt asset: ${file.path}');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// Minimal JSON that exercises the translation name / abbreviation mapping
/// without carrying any book data.
Map<String, dynamic> _stub({
  String? translation,
  String? name,
  String? abbreviation,
}) {
  return <String, dynamic>{
    'translation': translation,
    'metadata': <String, dynamic>{'name': name, 'abbreviation': abbreviation},
    'books': <dynamic>[],
  };
}

void main() {
  group('Bible.fromJson maps rebuilt assets to the right translation', () {
    test('drc.json loads as BibleTranslation.drc (not the cpdv fallback)', () {
      final Bible bible = Bible.fromJson(_asset('drc'));
      expect(bible.translation, BibleTranslation.drc);
    });

    test('engwebc.json loads as BibleTranslation.engwebc', () {
      final Bible bible = Bible.fromJson(_asset('engwebc'));
      expect(bible.translation, BibleTranslation.engwebc);
    });

    test('cpdv.json loads as BibleTranslation.cpdv', () {
      final Bible bible = Bible.fromJson(_asset('cpdv'));
      expect(bible.translation, BibleTranslation.cpdv);
    });

    test('every rebuilt asset maps to the enum its file id names', () {
      for (final MapEntry<String, BibleTranslation> entry
          in _expected.entries) {
        expect(Bible.fromJson(_asset(entry.key)).translation, entry.value);
      }
    });

    test('every rebuilt asset parses all 73 books', () {
      for (final String id in _expected.keys) {
        expect(Bible.fromJson(_asset(id)).books.length, 73, reason: '$id');
      }
    });
  });

  group('legacy translation spellings stay recognized', () {
    test('drc names and abbreviations', () {
      expect(
        Bible.fromJson(
          _stub(translation: 'Douay-Rheims 1899 American Edition (Challoner)'),
        ).translation,
        BibleTranslation.drc,
      );
      expect(
        Bible.fromJson(_stub(translation: 'Douay-Rheims 1899')).translation,
        BibleTranslation.drc,
      );
      expect(
        Bible.fromJson(_stub(translation: 'Douay-Rheims')).translation,
        BibleTranslation.drc,
      );
      expect(
        Bible.fromJson(
          _stub(translation: 'unrecognized', abbreviation: 'DRA'),
        ).translation,
        BibleTranslation.drc,
      );
      expect(
        Bible.fromJson(
          _stub(translation: 'unrecognized', abbreviation: 'DRC'),
        ).translation,
        BibleTranslation.drc,
      );
      expect(
        Bible.fromJson(
          _stub(translation: 'unrecognized', abbreviation: 'drc'),
        ).translation,
        BibleTranslation.drc,
      );
    });

    test('engwebc names and abbreviations', () {
      expect(
        Bible.fromJson(
          _stub(translation: 'World English Bible (Catholic Edition)'),
        ).translation,
        BibleTranslation.engwebc,
      );
      expect(
        Bible.fromJson(
          _stub(translation: 'World English Bible Catholic'),
        ).translation,
        BibleTranslation.engwebc,
      );
      expect(
        Bible.fromJson(_stub(translation: 'World English Bible')).translation,
        BibleTranslation.engwebc,
      );
      expect(
        Bible.fromJson(
          _stub(name: 'ignored', abbreviation: 'WEB-C'),
        ).translation,
        BibleTranslation.engwebc,
      );
      expect(
        Bible.fromJson(
          _stub(name: 'ignored', abbreviation: 'engwebc'),
        ).translation,
        BibleTranslation.engwebc,
      );
    });

    test('cpdv names and abbreviations', () {
      expect(
        Bible.fromJson(
          _stub(
            translation:
                'Catholic Public Domain Version '
                '(2009 Original Edition)',
          ),
        ).translation,
        BibleTranslation.cpdv,
      );
      expect(
        Bible.fromJson(
          _stub(translation: 'Catholic Public Domain Version'),
        ).translation,
        BibleTranslation.cpdv,
      );
      expect(
        Bible.fromJson(
          _stub(name: 'ignored', abbreviation: 'CPDV'),
        ).translation,
        BibleTranslation.cpdv,
      );
      expect(
        Bible.fromJson(
          _stub(name: 'ignored', abbreviation: 'cpdv'),
        ).translation,
        BibleTranslation.cpdv,
      );
    });
  });
}
