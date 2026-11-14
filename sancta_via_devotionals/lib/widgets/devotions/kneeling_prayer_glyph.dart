// Kneeling-prayer glyph: the devotions app's prayer motif, replacing the
// Material `self_improvement` (seated lotus meditation) glyph throughout
// the app — the seated pose read as Eastern meditation, which does not fit
// a Catholic devotional app; this figure kneels with folded hands.
//
// Source: Font Awesome Free "person-praying", CC BY 4.0 (Fonticons, Inc.),
// vendored at assets/icons/kneeling_prayer.svg; attribution is recorded in
// the app README. The asset is tinted through [IconTheme] so it recolors
// wherever a Material [Icon] would (navigation bars pass the selected/
// unselected color down through IconTheme).
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class KneelingPrayerGlyph extends StatelessWidget {
  const KneelingPrayerGlyph({super.key, this.size, this.color});

  /// Logical size; defaults to the surrounding [IconTheme] size.
  final double? size;

  /// Fill color; defaults to the surrounding [IconTheme] color (which
  /// Material navigation bars and buttons set per selection state).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final IconThemeData iconTheme = IconTheme.of(context);
    final Color resolvedColor = color ?? iconTheme.color ?? Colors.black87;
    final double resolvedSize = size ?? iconTheme.size ?? 24.0;
    return SvgPicture.asset(
      'assets/icons/kneeling_prayer.svg',
      width: resolvedSize,
      height: resolvedSize,
      colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcIn),
    );
  }
}
