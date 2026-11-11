// One-shot importer for the saint-for-that dataset (Task 4 of the
// saint-companion plan).
//
// Reads the sibling saint-for-that repository, extracts NEED_SYNONYMS from
// its taxonomy.ts, and writes the snapshot outputs Task 5's build consumes:
//   data/saints_source.json   raw records in sorted-slug order
//   data/needs_synonyms.json  [{need, synonyms}, ...] ported from taxonomy.ts
//   data/categories.json      the 10 category objects verbatim
//   data/manifest.json        via buildManifest (sha256 over snapshot bytes)
//
// Dev-only: tools/ is never imported by runtime code.
//
// Usage (from the package root):
//   dart run tools/fetch_snapshot.dart --source ../saint-for-that
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saint_data/src/db/manifest.dart';

/// The relative path of taxonomy.ts inside the source repo.
const String _taxonomyRelPath = 'site/src/lib/taxonomy.ts';

/// The 10 categories, verbatim from taxonomy.ts lines 8-17.
const List<Map<String, String>> _categories = <Map<String, String>>[
  <String, String>{
    'id': 'everyday',
    'label': 'Everyday life',
    'description': 'Lost items, housework, errands, daily needs',
  },
  <String, String>{
    'id': 'illness',
    'label': 'Illness & healing',
    'description': 'Diseases, mental health, specific conditions',
  },
  <String, String>{
    'id': 'jobs',
    'label': 'Jobs & professions',
    'description': 'Vocations, trades, occupations',
  },
  <String, String>{
    'id': 'travel',
    'label': 'Travel & transport',
    'description': 'Travelers, drivers, sailors, aviators',
  },
  <String, String>{
    'id': 'persecution',
    'label': 'Persecution & prisoners',
    'description': 'Martyrs, oppressed, prisoners, refugees',
  },
  <String, String>{
    'id': 'spiritual',
    'label': 'Spiritual life',
    'description': 'Doubt, conversion, prayer, temptations',
  },
  <String, String>{
    'id': 'military',
    'label': 'Military & first responders',
    'description': 'Soldiers, police, firefighters, EMS',
  },
  <String, String>{
    'id': 'family',
    'label': 'Children & family',
    'description': 'Children, mothers, fathers, fertility, marriage',
  },
  <String, String>{
    'id': 'nature',
    'label': 'Animals & nature',
    'description': 'Pets, ecology, environment, weather',
  },
  <String, String>{
    'id': 'special',
    'label': 'Special intentions',
    'description': 'Impossible causes, the dying, the poor',
  },
];

/// A structural failure while importing the source dataset.
class FetchSnapshotException implements Exception {
  /// Human-readable description of what went wrong.
  final String message;

  /// Creates an exception with [message].
  FetchSnapshotException(this.message);

  @override
  String toString() => message;
}

Future<void> main(List<String> args) async {
  try {
    await _run(args);
  } on FetchSnapshotException catch (error) {
    stderr.writeln('fetch_snapshot: $error');
    exitCode = 1;
  }
}

Future<void> _run(List<String> args) async {
  final String source = _parseSourceArg(args);
  final Directory saintsDir = Directory(p.join(source, 'data', 'saints'));
  final File taxonomyFile = File(p.join(source, _taxonomyRelPath));
  if (!saintsDir.existsSync()) {
    throw FetchSnapshotException('saints dir not found: ${saintsDir.path}');
  }
  if (!taxonomyFile.existsSync()) {
    throw FetchSnapshotException('taxonomy.ts not found: ${taxonomyFile.path}');
  }

  final String sourceCommit = await _readSourceCommit(source);

  // Extract NEED_SYNONYMS from taxonomy.ts.
  final Map<String, List<String>> synonyms = _extractNeedSynonyms(taxonomyFile);

  // Read every raw saint record and sort by slug.
  final List<Map<String, dynamic>> saints = <Map<String, dynamic>>[];
  for (final File file
      in saintsDir
          .listSync()
          .whereType<File>()
          .where((File f) => f.path.endsWith('.json'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path))) {
    final String text = file.readAsStringSync();
    saints.add(jsonDecode(text) as Map<String, dynamic>);
  }
  saints.sort(
    (Map<String, dynamic> a, Map<String, dynamic> b) =>
        (a['slug'] as String).compareTo(b['slug'] as String),
  );

  // Patronage category occurrence counts from the raw records.
  final Map<String, int> categoryCounts = <String, int>{
    for (final Map<String, String> category in _categories) category['id']!: 0,
  };
  for (final Map<String, dynamic> saint in saints) {
    final Object? patronages = saint['patronages'];
    if (patronages is List<Object?>) {
      for (final Object? patronage in patronages) {
        if (patronage is Map<Object?, Object?>) {
          final Object? categoryId = patronage['category'];
          if (categoryId is String && categoryCounts.containsKey(categoryId)) {
            categoryCounts[categoryId] = categoryCounts[categoryId]! + 1;
          }
        }
      }
    }
  }

  // Serialize snapshot outputs (trailing newline included in the hash).
  final Map<String, Object?> saintsPayload = <String, Object?>{
    'saints': saints,
  };
  final String saintsContent = '${_encoder.convert(saintsPayload)}\n';
  final String snapshotSha256 = sha256OfBytes(utf8.encode(saintsContent));

  final DateTime fetchedAt = DateTime.now().toUtc();
  final Map<String, Object> manifest = buildManifest(
    saintCount: saints.length,
    categoryCounts: categoryCounts,
    sourceRepo: source,
    sourceCommit: sourceCommit,
    fetchedAt: fetchedAt,
    snapshotSha256: snapshotSha256,
  );

  final Directory dataDir = Directory(p.join(Directory.current.path, 'data'));
  if (!dataDir.existsSync()) {
    dataDir.createSync(recursive: true);
  }
  _writeJson(p.join(dataDir.path, 'saints_source.json'), saintsPayload);
  _writeJson(p.join(dataDir.path, 'needs_synonyms.json'), <Map<String, Object>>[
    for (final MapEntry<String, List<String>> entry in synonyms.entries)
      <String, Object>{'need': entry.key, 'synonyms': entry.value},
  ]);
  _writeJson(p.join(dataDir.path, 'categories.json'), _categories);
  _writeJson(p.join(dataDir.path, 'manifest.json'), manifest);

  // Sanity echo of one synonym entry so the report can pin it.
  final List<String> lostItems = synonyms['lost items'] ?? <String>[];

  print('source: ${p.normalize(p.absolute(source))}');
  print('sourceCommit: $sourceCommit');
  print('saints: ${saints.length}');
  print('feastDay unknown: ${_countFeastDayUnknown(saints)}');
  print('with image: ${_countWithImage(saints)}');
  print(
    'synonym keys parsed: ${synonyms.length} '
    '(taxonomy.ts key lines: ${_keyLineCount})',
  );
  print(
    "'lost items' -> 'lost keys' present: ${lostItems.contains('lost keys')}",
  );
  print('categories written: ${_categories.length}');
  print('snapshotSha256: $snapshotSha256');
  print('manifest fetchedAt: ${manifest['fetchedAt']}');
  print('wrote: ${p.join(dataDir.path, 'saints_source.json')}');
  print('wrote: ${p.join(dataDir.path, 'needs_synonyms.json')}');
  print('wrote: ${p.join(dataDir.path, 'categories.json')}');
  print('wrote: ${p.join(dataDir.path, 'manifest.json')}');
}

/// Parses `--source` (default `../saint-for-that`).
String _parseSourceArg(List<String> args) {
  for (int i = 0; i < args.length; i++) {
    final String arg = args[i];
    if (arg == '--source' && i + 1 < args.length) {
      return args[i + 1];
    }
    if (arg.startsWith('--source=')) {
      return arg.substring('--source='.length);
    }
  }
  return '../saint-for-that';
}

/// HEAD commit of the source repo via a read-only git command.
Future<String> _readSourceCommit(String source) async {
  final ProcessResult result = await Process.run('git', <String>[
    '-C',
    source,
    'rev-parse',
    'HEAD',
  ]);
  if (result.exitCode != 0) {
    throw FetchSnapshotException('git rev-parse failed: ${result.stderr}');
  }
  return (result.stdout as String).trim();
}

/// Key-line count captured while extracting (printed next to the parsed
/// count so the two can be verified against each other).
int _keyLineCount = 0;

/// Extracts NEED_SYNONYMS from the taxonomy.ts file.
///
/// The block between `export const NEED_SYNONYMS` and its closing `};` is
/// parsed with a regex capturing `'key': ['a', ...]` pairs, tolerating
/// JSON5-style single quotes and trailing commas. The parsed key count must
/// match the raw key-line count in the TS block.
Map<String, List<String>> _extractNeedSynonyms(File taxonomyFile) {
  final String source = taxonomyFile.readAsStringSync();
  final int start = source.indexOf('export const NEED_SYNONYMS');
  if (start < 0) {
    throw FetchSnapshotException('NEED_SYNONYMS not found in taxonomy.ts');
  }
  final int end = source.indexOf('};', start);
  if (end < 0) {
    throw FetchSnapshotException('NEED_SYNONYMS block not closed');
  }
  final String block = source.substring(start, end);
  final String body = block.substring(block.indexOf('{') + 1);

  _keyLineCount = RegExp(r"^\s{2}'", multiLine: true).allMatches(block).length;

  final RegExp pairPattern = RegExp(
    r"'((?:[^'\\]|\\.)*)'\s*:\s*\[(.*?)\]",
    dotAll: true,
  );

  final Map<String, List<String>> synonyms = <String, List<String>>{};
  for (final RegExpMatch match in pairPattern.allMatches(body)) {
    final String key = match.group(1)!;
    final String arraySource = _json5ToStringArray(match.group(2)!);
    final Object? decoded = jsonDecode(arraySource);
    if (decoded is! List<Object?>) {
      throw FetchSnapshotException('not a list for key "$key"');
    }
    synonyms[key] = decoded.cast<String>();
  }
  if (synonyms.isEmpty) {
    throw FetchSnapshotException('no NEED_SYNONYMS entries parsed');
  }
  if (synonyms.length != _keyLineCount) {
    throw FetchSnapshotException(
      'synonym key count mismatch: parsed ${synonyms.length} vs '
      '${_keyLineCount} key lines in taxonomy.ts',
    );
  }
  return synonyms;
}

/// Converts a single-quoted, possibly trailing-comma array body into strict
/// JSON by swapping quotes and dropping trailing commas.
String _json5ToStringArray(String body) {
  final String withoutTrailingCommas = body.replaceAllMapped(
    RegExp(r',\s*\]'),
    (Match match) => ']',
  );
  return '[${withoutTrailingCommas.replaceAll("'", '"')}]';
}

int _countFeastDayUnknown(List<Map<String, dynamic>> saints) {
  int count = 0;
  for (final Map<String, dynamic> saint in saints) {
    if (saint['feastDay'] == 'unknown') {
      count++;
    }
  }
  return count;
}

int _countWithImage(List<Map<String, dynamic>> saints) {
  int count = 0;
  for (final Map<String, dynamic> saint in saints) {
    final Object? image = saint['image'];
    if (image is Map && image.isNotEmpty) {
      count++;
    }
  }
  return count;
}

/// Pretty encoder used for all snapshot outputs.
const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

/// Serializes [data] to [path], pretty-printed with a trailing newline.
void _writeJson(String path, Object? data) {
  File(path).writeAsStringSync('${_encoder.convert(data)}\n');
}
