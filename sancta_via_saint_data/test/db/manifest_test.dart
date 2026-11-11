import 'package:flutter_test/flutter_test.dart';
import 'package:saint_data/src/db/manifest.dart';

void main() {
  group('sha256OfBytes', () {
    test('hashes "abc" to the known sha256 digest', () {
      final String digest = sha256OfBytes('abc'.codeUnits);
      expect(
        digest,
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('hashes empty input to the known empty sha256 digest', () {
      final String digest = sha256OfBytes(<int>[]);
      expect(
        digest,
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('differs for different inputs', () {
      final String a = sha256OfBytes('abc'.codeUnits);
      final String b = sha256OfBytes('abd'.codeUnits);
      expect(a, isNot(b));
    });
  });

  group('buildManifest', () {
    test('fills every manifest key from its inputs', () {
      final DateTime fetched = DateTime.utc(2026, 11, 11, 12, 30);
      final Map<String, Object> manifest = buildManifest(
        saintCount: 2174,
        categoryCounts: <String, int>{'everyday': 401, 'illness': 204},
        sourceRepo: '/Users/jason/Repos/saint-for-that',
        sourceCommit: '8d5d73585b6f4bab3beaaa456cb5c28721b82f76',
        fetchedAt: fetched,
        snapshotSha256: 'abc123',
      );

      expect(manifest['sourceRepo'], '/Users/jason/Repos/saint-for-that');
      expect(
        manifest['sourceCommit'],
        '8d5d73585b6f4bab3beaaa456cb5c28721b82f76',
      );
      expect(manifest['fetchedAt'], '2026-11-11T12:30:00.000Z');
      expect(manifest['saintCount'], 2174);
      expect(manifest['categoryCounts'], <String, int>{
        'everyday': 401,
        'illness': 204,
      });
      expect(manifest['snapshotSha256'], 'abc123');
    });

    test('exposes exactly the manifest key set', () {
      final Map<String, Object> manifest = buildManifest(
        saintCount: 1,
        categoryCounts: <String, int>{'everyday': 0},
        sourceRepo: 'repo',
        sourceCommit: 'commit',
        fetchedAt: DateTime.utc(2026),
        snapshotSha256: 'sha',
      );

      expect(manifest.keys.toSet(), <String>{
        'sourceRepo',
        'sourceCommit',
        'fetchedAt',
        'saintCount',
        'categoryCounts',
        'snapshotSha256',
      });
    });

    test('serializes a local fetchedAt time as UTC ISO-8601', () {
      final Map<String, Object> manifest = buildManifest(
        saintCount: 0,
        categoryCounts: <String, int>{},
        sourceRepo: 'repo',
        sourceCommit: 'commit',
        fetchedAt: DateTime(2026, 11, 11, 5),
        snapshotSha256: 'sha',
      );

      final String expected = DateTime(
        2026,
        11,
        11,
        5,
      ).toUtc().toIso8601String();
      expect(manifest['fetchedAt'], expected);
    });
  });
}
