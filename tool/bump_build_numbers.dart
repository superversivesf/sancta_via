// Increments the Flutter build number (`+N`) in every app pubspec.yaml of the
// Sancta Via workspace. An app is a `sancta_via_*` directory that contains both
// a pubspec.yaml and lib/main.dart. Run via `melos run version:bump:build`.
//
// Usage: dart run tool/bump_build_numbers.dart [targetDir]
import 'dart:io';
import 'dart:math' as math;

final RegExp _versionPattern = RegExp(r'^version: (\d+\.\d+\.\d+)(\+(\d+))?\s*$');

Match? _firstMatchOrNull(String line) => _versionPattern.firstMatch(line);

void main(List<String> args) {
  final target = Directory(args.isNotEmpty ? args[0] : '.');
  if (!target.existsSync()) {
    stderr.writeln('error: target directory not found: ${target.path}');
    exit(1);
  }

  final candidates = target
      .listSync()
      .whereType<Directory>()
      .where((d) => '${d.path.split(Platform.pathSeparator).last}'.startsWith('sancta_via_'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final apps = candidates
      .where((d) => File('${d.path}${Platform.pathSeparator}lib${Platform.pathSeparator}main.dart').existsSync())
      .toList();

  if (apps.isEmpty) {
    stderr.writeln('error: no app directories found under ${target.path}');
    exit(1);
  }

  var failed = false;
  final rows = <List<String>>[];
  for (final app in apps) {
    final name = app.path.split(Platform.pathSeparator).last;
    final pubspec = File('${app.path}${Platform.pathSeparator}pubspec.yaml');
    final lines = pubspec.readAsLinesSync();
    final idx = lines.indexWhere((l) => l.startsWith('version:'));
    if (idx < 0 || _firstMatchOrNull(lines[idx]) == null) {
      final shown = idx >= 0 ? lines[idx] : '(no version line at all)';
      stderr.writeln(
          'error: no parsable "version: X.Y.Z[+N]" line in ${pubspec.path}: $shown');
      failed = true;
      rows.add([name, '(unparsable)', '(unparsable)']);
      continue;
    }
    final m = _firstMatchOrNull(lines[idx])!;
    final base = m.group(1)!;
    final current = int.parse(m.group(3) ?? '0');
    final next = math.max(current + 1, 1);
    rows.add([name, lines[idx].trim(), 'version: $base+$next']);
    lines[idx] = 'version: $base+$next';
    pubspec.writeAsStringSync('${lines.join('\n')}\n');
  }

  for (final row in rows) {
    print('* ${row[0]}: ${row[1]} -> ${row[2]}');
  }
  if (failed) exit(1);
}
