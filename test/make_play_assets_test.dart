import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';

void main() {
  late Directory fixture;

  setUp(() {
    fixture = Directory.systemTemp.createTempSync('make_play_assets');
  });

  tearDown(() {
    fixture.deleteSync(recursive: true);
  });

  /// A 64x64 app icon with a solid red background and a blue square centre.
  String makeApp(String name) {
    final dir = Directory('${fixture.path}/sancta_via_$name')
      ..createSync(recursive: true);
    Directory('${dir.path}/assets').createSync();
    Directory('${dir.path}/lib').createSync();
    File('${dir.path}/lib/main.dart').writeAsStringSync('void main() {}\n');
    final icon = img.Image(width: 64, height: 64);
    img.fill(icon, color: img.ColorRgb8(200, 30, 40));
    img.fillRect(icon,
        x1: 16, y1: 16, x2: 48, y2: 48, color: img.ColorRgb8(10, 20, 230));
    final iconPath = '${dir.path}/assets/app_icon.png';
    File(iconPath).writeAsBytesSync(img.encodePng(icon));
    return iconPath;
  }

  test('creates 512 store icon, 1024x500 feature graphic, padded foreground',
      () async {
    makeApp('alpha');

    final result = await Process.run(
      'dart',
      ['run', 'tool/make_play_assets.dart', fixture.path],
      workingDirectory: Directory.current.path,
    );
    expect(result.exitCode, 0, reason: result.stderr.toString());

    final play512 = File('${fixture.path}/releases_assets/play/alpha-512.png');
    final feature = File('${fixture.path}/releases_assets/play/alpha-feature.png');
    final foreground =
        File('${fixture.path}/sancta_via_alpha/assets/app_icon_foreground.png');
    expect(play512.existsSync(), isTrue);
    expect(feature.existsSync(), isTrue);
    expect(foreground.existsSync(), isTrue);

    final i512 = img.decodePng(play512.readAsBytesSync())!;
    expect(i512.width, 512);
    expect(i512.height, 512);

    final feat = img.decodePng(feature.readAsBytesSync())!;
    expect(feat.width, 1024);
    expect(feat.height, 500);

    // Feature graphic background is the icon's sampled corner colour.
    final corner = feat.getPixel(4, 4);
    expect(corner.r.toInt(), 200);
    expect(corner.g.toInt(), 30);
    expect(corner.b.toInt(), 40);

    // Foreground: transparent at the corners, icon content in the middle,
    // scaled down so the visible glyph sits inside the adaptive safe zone.
    final fg = img.decodePng(foreground.readAsBytesSync())!;
    expect(fg.width, 1024);
    expect(fg.height, 1024);
    expect(fg.getPixel(2, 2).a.toInt(), 0, reason: 'corners transparent');
    expect(fg.getPixel(512, 512).a.toInt(), 255, reason: 'centre has content');
  });

  test('ignores directories without lib/main.dart', () async {
    makeApp('alpha');
    final notApp = Directory('${fixture.path}/sancta_via_core_lib')..createSync();
    File('${notApp.path}/pubspec.yaml').writeAsStringSync('name: x\n');

    final result = await Process.run(
      'dart',
      ['run', 'tool/make_play_assets.dart', fixture.path],
      workingDirectory: Directory.current.path,
    );
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(
        Directory('${fixture.path}/releases_assets/play/core_lib').existsSync(),
        isFalse);
    expect(File('${notApp.path}/assets/app_icon_foreground.png').existsSync(),
        isFalse);
  });
}
