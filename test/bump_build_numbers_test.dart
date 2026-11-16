import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Directory fixture;

  setUp(() {
    fixture = Directory.systemTemp.createTempSync('bump_build_numbers');
  });

  tearDown(() {
    fixture.deleteSync(recursive: true);
  });

  /// Write <name>/pubspec.yaml with the given version and lib/main.dart so the
  /// tool treats it as an app.
  String makeApp(String name, String version) {
    final dir = Directory('${fixture.path}/sancta_via_$name')
      ..createSync(recursive: true);
    Directory('${dir.path}/lib').createSync();
    File('${dir.path}/lib/main.dart')
        .writeAsStringSync('void main() {}\n');
    File('${dir.path}/pubspec.yaml')
        .writeAsStringSync('# Version: major.minor.patch+build\nversion: $version\n');
    return version;
  }

  String readVersion(String name) {
    return _versionLine('${fixture.path}/sancta_via_$name/pubspec.yaml');
  }

  test(
    'adds +1 to a bare version and increments an existing +N, '
    'leaving non-app packages untouched',
    () async {
      makeApp('alpha', '1.1.57');
      makeApp('beta', '1.2.0+4');
      // Has pubspec.yaml but no lib/main.dart: a package, not an app.
      final pkg = Directory('${fixture.path}/sancta_via_core_lib')..createSync();
      File('${pkg.path}/pubspec.yaml').writeAsStringSync('version: 9.9.9\n');

      final run1 = await Process.run(
        'dart',
        ['run', 'tool/bump_build_numbers.dart', fixture.path],
        workingDirectory: Directory.current.path,
      );

      expect(run1.exitCode, 0, reason: run1.stderr.toString());
      expect(readVersion('alpha'), 'version: 1.1.57+1');
      expect(readVersion('beta'), 'version: 1.2.0+5');
      expect(
        _versionLine('${pkg.path}/pubspec.yaml'),
        'version: 9.9.9',
        reason: 'packages without lib/main.dart must not be bumped',
      );

      // A second run keeps incrementing (monotonic per app).
      final run2 = await Process.run(
        'dart',
        ['run', 'tool/bump_build_numbers.dart', fixture.path],
        workingDirectory: Directory.current.path,
      );
      expect(run2.exitCode, 0, reason: run2.stderr.toString());
      expect(readVersion('beta'), 'version: 1.2.0+6');
      expect(readVersion('alpha'), 'version: 1.1.57+2');
    },
  );

  test('exits non-zero when a version line is malformed', () async {
    makeApp('broken', 'not-a-version');
    final result = await Process.run(
      'dart',
      ['run', 'tool/bump_build_numbers.dart', fixture.path],
      workingDirectory: Directory.current.path,
    );
    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('not-a-version'));
  });
}

String _versionLine(String pubspecPath) {
  return File(pubspecPath)
      .readAsLinesSync()
      .where((l) => l.startsWith('version:'))
      .single;
}
