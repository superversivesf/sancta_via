// Companion-prayer import (Plan 2, Task 21).
//
// Reads every prayer JSON in the prayer companion's assets
// (`sancta_via_prayer_companion/assets/prayers/*.json`, READ-ONLY — the
// companion's assets are the source of truth for the TEXTS; copying them into
// this app is the point) and maps the companion schema onto the engine's
// [PrayerText] entries:
//
//   companion `id`/`text`/`translation.latin` → PrayerText id/text/latin
//   companion `attribution`                  → PrayerText source
//   classified from the attribution          → PrayerText license
//
// Anything missing source or license is DROPPED and printed to stdout as a
// `rejected` line (the committed rejected list is pinned by
// `test/content/routine_packs_test.dart`, so a companion edit that silently
// changes the accepted/rejected split cannot ship unnoticed): the engine's
// [PrayerText] constructor rejects empty source/license, and this tool's
// license classification only rules on attributions it can vouch for.
//
// Classification policy (first match wins; conservative on purpose):
//
// 1. Attribution absent            → rejected (no source to attribute).
// 2. Roman Missal / Martyrology    → rejected (ICEL-era liturgical editions;
//                                    the English renderings need an explicit
//                                    licensing ruling first).
// 3. Liturgy of the Hours          → rejected (same ICEL/Grail-era concern as
//                                    the Roman Missal rule).
// 4. Pope Francis (2021 expansions)→ rejected (modern expansion of an
//                                    otherwise public-domain litany).
// 5. `Traditional …`               → public-domain.
// 6. `Based on <Scripture>` / the
//    Lord's Prayer                 → public-domain (scriptural formula).
// 7. Dated antiquity (century or
//    pre-1600 year markers)        → public-domain (ancient attribution).
// 8. Anything else                 → public-domain (attributed, pre-1928);
//                                    the companion only attributes such texts
//                                    to pre-1928 publications or widely
//                                    reproduced traditional forms.
//
// Writes `assets/content/prayers/<id>.json` (the engine's PrayerText JSON,
// one file per prayer) and is idempotent/re-runnable: the committed output is
// checked in, and re-running regenerates it byte-for-byte.
library;

import 'dart:convert';
import 'dart:io';

import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';

/// Directory holding the prayer companion's prayer assets (READ-ONLY input;
/// the companions's own assets remain its package's source of truth).
const String companionAssetsDir =
    '../sancta_via_prayer_companion/assets/prayers';

/// Where the imported PrayerText JSON files are written.
const String importedAssetsDir = 'assets/content/prayers';

/// The companion metadata file, which is an index, not a prayer.
const String _metadataFileName = 'prayers_metadata.json';

/// One companion prayer's import verdict: the mapped [PrayerText] when
/// accepted, or the rejection reason when dropped.
class ImportedPrayer {
  const ImportedPrayer._({required this.id, this.prayer, this.rejection});

  /// The mapped prayer (null when the verdict is a rejection).
  final PrayerText? prayer;

  /// The rejection reason (null when accepted).
  final String? rejection;

  /// The companion id.
  final String id;

  bool get accepted => prayer != null;
}

/// The whole import run: accepted prayers by id, rejections by id.
class ImportOutcome {
  const ImportOutcome({required this.accepted, required this.rejected});

  /// id → mapped [PrayerText], in companion filename order.
  final Map<String, PrayerText> accepted;

  /// id → rejection reason, in companion filename order.
  final Map<String, String> rejected;

  int get acceptedCount => accepted.length;
  int get rejectedCount => rejected.length;
}

/// Maps ONE companion prayer JSON onto an [ImportedPrayer] verdict.
///
/// Pure: no filesystem access; `main` composes this with the directory read.
/// The [PrayerText] constructor is the last line of defense — an empty
/// source or license surfaces as a rejection here instead of an unshippable
/// text.
ImportedPrayer mapCompanionPrayer(Map<String, Object?> json) {
  final Object? idValue = json['id'];
  if (idValue is! String || idValue.isEmpty) {
    // A companion file without an id cannot be named in an output file at
    // all; callers never hit this with the real assets (every file has an
    // id), so the fallback keeps the verdict shape total.
    return const ImportedPrayer._(id: '<unnamed>', rejection: 'no id field');
  }
  final Object? text = json['text'];
  if (text is! String || text.isEmpty) {
    return ImportedPrayer._(id: idValue, rejection: 'no prayer text');
  }

  final Object? attribution = json['attribution'];
  if (attribution is! String || attribution.trim().isEmpty) {
    return ImportedPrayer._(
      id: idValue,
      rejection: 'no attribution (companion metadata omits it)',
    );
  }

  final String? rejection = _licenseRejection(attribution);
  if (rejection != null) {
    return ImportedPrayer._(id: idValue, rejection: rejection);
  }

  final String? latin = _latinOf(json['translation']);
  try {
    return ImportedPrayer._(
      id: idValue,
      prayer: PrayerText(
        id: idValue,
        text: text,
        latin: latin,
        source: attribution,
        license: _licenseFor(attribution),
      ),
    );
  } on Object catch (e) {
    return ImportedPrayer._(id: idValue, rejection: 'failed validation: $e');
  }
}

/// The deterministic file encoding of one imported prayer (what
/// `runImport` writes and the pin test joins against).
String encodedPrayerJson(PrayerText prayer) {
  const JsonEncoder encoder = JsonEncoder.withIndent('  ');
  return '${encoder.convert(prayer.toJson())}\n';
}

/// Reads every companion prayer JSON (the metadata file skipped), filename
/// order. Callers hand the entries to [mapCompanionPrayer] one by one.
Map<String, Map<String, Object?>> loadCompanionPrayers(String dir) {
  final Directory directory = Directory(dir);
  final List<String> paths = <String>[
    for (final FileSystemEntity entry in directory.listSync())
      if (entry is File &&
          entry.path.endsWith('.json') &&
          !_isMetadataFile(entry.path))
        entry.path,
  ]..sort();
  return <String, Map<String, Object?>>{
    for (final String path in paths)
      _fileId(path):
          jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>,
  };
}

/// Runs the import end to end: maps every companion prayer under [dir] and
/// writes the accepted ones (the engine PrayerText JSON) under [outDir].
/// Existing files are overwritten in place; files for prayers that are no
/// longer accepted are NOT deleted (the pin test catches stray committed
/// output), keeping the tool's write side additive.
ImportOutcome runImport({String? dir, String? outDir}) {
  final String companionDir = dir ?? companionAssetsDir;
  final String outputDir = outDir ?? importedAssetsDir;
  final Map<String, PrayerText> accepted = <String, PrayerText>{};
  final Map<String, String> rejected = <String, String>{};
  Directory(outputDir).createSync(recursive: true);
  for (final MapEntry<String, Map<String, Object?>> entry
      in loadCompanionPrayers(companionDir).entries) {
    final ImportedPrayer verdict = mapCompanionPrayer(entry.value);
    if (verdict.accepted) {
      accepted[verdict.id] = verdict.prayer!;
      File(
        '$outputDir/${verdict.id}.json',
      ).writeAsStringSync(encodedPrayerJson(verdict.prayer!));
    } else {
      rejected[verdict.id] = verdict.rejection!;
    }
  }
  return ImportOutcome(accepted: accepted, rejected: rejected);
}

void main() {
  final ImportOutcome outcome = runImport();
  stdout.writeln(
    'companion import: ${outcome.acceptedCount} accepted, '
    '${outcome.rejectedCount} rejected → $importedAssetsDir',
  );
  for (final String id in outcome.accepted.keys) {
    stdout.writeln('accepted $id');
  }
  for (final MapEntry<String, String> entry in outcome.rejected.entries) {
    stdout.writeln('rejected ${entry.key}: ${entry.value}');
  }
}

/// Reject rules 2–4 above; null when the attribution has no rejection.
String? _licenseRejection(String attribution) {
  if (attribution.contains('Roman Missal') ||
      attribution.contains('Roman Martyrology')) {
    return 'ICEL-era liturgical edition (Roman Missal/Martyrology) — needs an '
        'explicit license ruling first';
  }
  if (attribution.contains('Liturgy of the Hours')) {
    return 'ICEL/Grail-era Liturgy of the Hours English — needs an explicit '
        'license ruling first';
  }
  if (attribution.contains('Pope Francis')) {
    return 'carries a modern (2021) expansion; the base is public-domain but '
        'the file text is not separable — needs an explicit license ruling '
        'first';
  }
  return null;
}

/// Classify rules 5–8 above.
String _licenseFor(String attribution) {
  if (attribution.startsWith('Traditional')) {
    return 'public-domain';
  }
  if (attribution.contains('Based on') || attribution.startsWith('Jesus ')) {
    return 'public-domain (scriptural formula)';
  }
  if (_ancientMarker.hasMatch(attribution)) {
    return 'public-domain (ancient attribution)';
  }
  return 'public-domain (attributed, pre-1928)';
}

/// Century / dated-antiquity markers: `Ancient`, `13th Century`, `c. 1264`,
/// a pre-1600 year, and so on. (Case-insensitive via the constructor — the
/// engine rejects a literal `(?i)` inline flag.)
final RegExp _ancientMarker = RegExp(
  r'(ancient|\d{1,2}(st|nd|rd|th)?[ -]?century|c\.\s*\d|\b1[0-5]\d{2}\b)',
  caseSensitive: false,
);

/// The companion `translation` object's Latin, when present.
String? _latinOf(Object? translation) {
  if (translation is! Map<String, Object?>) {
    return null;
  }
  final Object? latin = translation['latin'];
  if (latin is String && latin.isNotEmpty) {
    return latin;
  }
  return null;
}

bool _isMetadataFile(String path) =>
    path.split(Platform.pathSeparator).last == _metadataFileName;

/// The companion prayer's stable id == the file stem (every companion file
/// carries a matching `id` field; the tool asserts that with
/// [mapCompanionPrayer]'s id pass-through).
String _fileId(String path) =>
    path.split(Platform.pathSeparator).last.replaceAll('.json', '');
