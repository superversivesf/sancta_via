import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Builds the snapshot manifest written to `data/manifest.json`.
///
/// The manifest records where and when the saint-for-that dataset was
/// imported, how many saints it contains, how many patronage entries fall
/// in each category, and the sha-256 of the serialized snapshot, so that
/// downstream builds (and tests) can verify what they read.
Map<String, Object> buildManifest({
  required int saintCount,
  required Map<String, int> categoryCounts,
  required String sourceRepo,
  required String sourceCommit,
  required DateTime fetchedAt,
  required String snapshotSha256,
}) {
  return <String, Object>{
    'sourceRepo': sourceRepo,
    'sourceCommit': sourceCommit,
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    'saintCount': saintCount,
    'categoryCounts': categoryCounts,
    'snapshotSha256': snapshotSha256,
  };
}

/// Returns the lowercase hex sha-256 digest of [bytes].
String sha256OfBytes(List<int> bytes) {
  return sha256.convert(bytes).toString();
}

/// Convenience wrapper: sha-256 of a UTF-8 encoded string.
String sha256OfString(String text) {
  return sha256OfBytes(utf8.encode(text));
}
