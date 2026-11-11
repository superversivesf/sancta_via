// Fixture-run test for `tools/build_saints_db.dart` draft-exclusion semantics.
//
// The build tool resolves its inputs from `Directory.current`, so this test
// stages a tiny synthetic snapshot under `.dart_tool/` (inside the package,
// so `dart run` package resolution finds the real package config), copies the
// real tool there, and runs it as a subprocess. The fixture carries ONE
// `draft: true` record and a manifest describing only the non-draft records:
// the draft must be skipped without failing the saintCount cross-check
// (the design's documented exclusion mechanism).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory fixture;

  setUp(() {
    // Under `.dart_tool/` so ancestor package-config discovery still hits the
    // real package, and the fixture never touches committed data.
    fixture = Directory(
      '${Directory.current.path}/.dart_tool/'
      'fixture-build-saints-db-${DateTime.now().microsecondsSinceEpoch}',
    );
    Directory('${fixture.path}/data').createSync(recursive: true);
    Directory('${fixture.path}/tools').createSync(recursive: true);

    // The tool under test, copied verbatim.
    final String toolSource = File(
      '${Directory.current.path}/tools/build_saints_db.dart',
    ).readAsStringSync();
    File(
      '${fixture.path}/tools/build_saints_db.dart',
    ).writeAsStringSync(toolSource);

    // Two live records + one draft. Categories must be real SaintCategory
    // ids (the model rejects unknown ids during validation).
    _writeJson('${fixture.path}/data/categories.json', <Object>[
      <String, String>{
        'id': 'everyday',
        'label': 'Everyday life',
        'description': 'Lost items, housework, errands, daily needs',
      },
      <String, String>{
        'id': 'spiritual',
        'label': 'Spiritual life',
        'description': 'Doubt, conversion, prayer, temptations',
      },
    ]);
    _writeJson('${fixture.path}/data/needs_synonyms.json', <Object>[
      <String, Object>{
        'need': 'monks',
        'synonyms': <String>['monastic fathers'],
      },
    ]);
    _writeJson('${fixture.path}/data/saints_source.json', <String, Object>{
      'saints': <Object>[
        _saintA,
        _saintB,
        _saintC, // the draft: must be skipped, never counted
      ],
    });
    // The manifest describes the inserted set only: 2 saints and the
    // patronage categories of A (2 entries) + B (1 entry).
    _writeJson('${fixture.path}/data/manifest.json', <String, Object>{
      'sourceRepo': 'fixture',
      'sourceCommit': 'fixture',
      'fetchedAt': '2026-11-12T00:00:00.000Z',
      'saintCount': 2,
      'categoryCounts': <String, int>{'everyday': 1, 'spiritual': 2},
      'snapshotSha256': 'fixture',
    });
  });

  tearDown(() {
    if (fixture.existsSync()) {
      fixture.deleteSync(recursive: true);
    }
  });

  test(
    'a draft record is skipped without failing the manifest cross-check',
    () async {
      final ProcessResult result = await Process.run(
        _dartExecutable(),
        <String>['run', 'tools/build_saints_db.dart'],
        workingDirectory: fixture.path,
      );

      // PRE-FIX FAILURE MODE: the cross-check compared records.length (3,
      // including the draft) against the manifest's 2, so any snapshot with a
      // draft record made the build exit 1. The cross-check must use the
      // inserted count instead.
      expect(
        result.exitCode,
        0,
        reason:
            'build with one draft record must succeed; stderr: '
            '${result.stderr}',
      );
      final String stdout = result.stdout as String;
      expect(stdout, contains('records: 3 (drafts skipped: 1)'));
      // The cross-check line counts the inserted set, not the raw record set.
      expect(
        stdout,
        contains('manifest cross-check: saintCount 2 == 2 inserted'),
        reason: 'saintCount compares against the 2 non-draft records inserted',
      );
      expect(stdout, contains('saints rows: 2'));
      expect(stdout, contains('patronages rows: 3'));
      expect(stdout, contains('need_synonyms: 1 entries -> 1 rows'));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

/// The `dart` CLI to spawn `dart run` with: tests execute inside the
/// flutter_tester engine binary, so [Platform.resolvedExecutable] cannot
/// launch a dart command. [Platform.environment] carries FLUTTER_ROOT when
/// the flutter tool is the parent process; its pinned dart-sdk is used.
String _dartExecutable() {
  final String? flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final String dartSdk = '$flutterRoot/bin/cache/dart-sdk/bin/dart';
    if (File(dartSdk).existsSync()) {
      return dartSdk;
    }
    final String wrapper = '$flutterRoot/bin/dart';
    if (File(wrapper).existsSync()) {
      return wrapper;
    }
  }
  // Fall back to a PATH lookup (plain `dart test` or manual runs).
  return 'dart';
}

/// A live fixture record with two patronages.
const Map<String, Object> _saintA = <String, Object>{
  'slug': 'fixture-saint-a',
  'name': 'St. Fixture A',
  'feastDay': '05-04',
  'bio': 'Fixture saint A for the draft exclusion cross-check test.',
  'patronages': <Object>[
    <String, String>{'need': 'monks', 'category': 'spiritual'},
    <String, String>{'need': 'lost keys', 'category': 'everyday'},
  ],
  'prayer': <String, String>{
    'text': 'Pray for us, fixture saint A.',
    'source': 'original',
  },
  'sources': <String>[],
  'featured': true,
  'draft': false,
};

/// A live fixture record with one patronage, no prayer.
const Map<String, Object> _saintB = <String, Object>{
  'slug': 'fixture-saint-b',
  'name': 'St. Fixture B',
  'bio': 'Fixture saint B for the draft exclusion cross-check test.',
  'patronages': <Object>[
    <String, String>{'need': 'monks', 'category': 'spiritual'},
  ],
  'sources': <String>[],
  'featured': false,
  'draft': false,
};

/// The draft fixture record: excluded from validation and insertion.
const Map<String, Object> _saintC = <String, Object>{
  'slug': 'fixture-saint-c',
  'name': 'St. Fixture C',
  'bio': 'Draft fixture saint C that must be skipped, not counted.',
  'patronages': <Object>[
    <String, String>{'need': 'monks', 'category': 'spiritual'},
  ],
  'sources': <String>[],
  'featured': false,
  'draft': true,
};

/// Serializes [data] to [path], pretty-printed with a trailing newline.
void _writeJson(String path, Object data) {
  File(
    path,
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(data)}\n');
}
