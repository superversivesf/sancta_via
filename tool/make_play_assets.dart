// Generates Play-store image assets and flutter_launcher_icons foreground
// sources from each app's `assets/app_icon.png` (must be square).
//
// Per app (a `sancta_via_*` directory with lib/main.dart and assets/app_icon.png):
//   assets/app_icon_foreground.png   1024x1024, icon at ~66% on transparent
//                                    canvas (adaptive-icon foreground layer)
//   releases_assets/play/<app>-512.png      512x512 store listing icon
//   releases_assets/play/<app>-feature.png  1024x500, background = sampled
//                                           icon corner colour
//
// Usage: dart run tool/make_play_assets.dart [targetDir]
import 'dart:io';

import 'package:image/image.dart' as img;

const int _canvasSize = 1024;
const double _foregroundScale = 0.66; // icon within adaptive safe zone

void main(List<String> args) {
  final target = Directory(args.isNotEmpty ? args[0] : '.');
  if (!target.existsSync()) {
    stderr.writeln('error: target directory not found: ${target.path}');
    exit(1);
  }

  final apps = target
      .listSync()
      .whereType<Directory>()
      .where((d) =>
          d.path.split(Platform.pathSeparator).last.startsWith('sancta_via_') &&
          File('${d.path}/lib/main.dart').existsSync() &&
          File('${d.path}/assets/app_icon.png').existsSync())
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (apps.isEmpty) {
    stderr.writeln('error: no apps with assets/app_icon.png under ${target.path}');
    exit(1);
  }

  final playDir = Directory('${target.path}/releases_assets/play')
    ..createSync(recursive: true);

  for (final app in apps) {
    final dirName = app.path.split(Platform.pathSeparator).last;
    final name = dirName.startsWith('sancta_via_')
        ? dirName.substring('sancta_via_'.length)
        : dirName;
    final icon = img.decodePng(
        File('${app.path}/assets/app_icon.png').readAsBytesSync());
    if (icon == null || icon.width != icon.height) {
      stderr.writeln('error: $name assets/app_icon.png missing or not square');
      exit(1);
    }

    final bg = icon.getPixel(4, 4);

    // Store icon: full-bleed square, 512x512.
    File('${playDir.path}/$name-512.png').writeAsBytesSync(
        img.encodePng(img.copyResize(icon, width: 512, height: 512,
            interpolation: img.Interpolation.cubic)));

    // Feature graphic: 1024x500, background fill from sampled corner, icon
    // centred at ~40% of the graphic's height.
    final feature = img.Image(width: _canvasSize, height: 500);
    img.fill(feature,
        color: img.ColorRgb8(bg.r.toInt(), bg.g.toInt(), bg.b.toInt()));
    final featureIcon = img.copyResize(icon,
        width: (500 * 0.4 * icon.width / icon.height).round(),
        height: 200,
        interpolation: img.Interpolation.cubic);
    img.compositeImage(feature, featureIcon,
        dstX: (_canvasSize - featureIcon.width) ~/ 2,
        dstY: (500 - 200) ~/ 2);
    File('${playDir.path}/$name-feature.png')
        .writeAsBytesSync(img.encodePng(feature));

    // Adaptive-icon foreground: icon scaled onto a transparent canvas.
    final fg = img.Image(
        width: _canvasSize,
        height: _canvasSize,
        numChannels: 4); // RGBA: corners must be transparent
    final fgSide = (_canvasSize * _foregroundScale).round();
    final fgIcon = img.copyResize(icon,
        width: fgSide, height: fgSide,
        interpolation: img.Interpolation.cubic);
    img.compositeImage(fg, fgIcon,
        dstX: (_canvasSize - fgSide) ~/ 2, dstY: (_canvasSize - fgSide) ~/ 2);
    File('${app.path}/assets/app_icon_foreground.png')
        .writeAsBytesSync(img.encodePng(fg));

    print('* $name: 512 + feature(1024x500) + foreground written; '
        'bg=#${bg.r.toInt().toRadixString(16).padLeft(2, '0')}'
        '${bg.g.toInt().toRadixString(16).padLeft(2, '0')}'
        '${bg.b.toInt().toRadixString(16).padLeft(2, '0')}');
  }
}
