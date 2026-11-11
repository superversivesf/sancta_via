import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:saint_data/saint_data.dart';

/// Lowercases [need] and maps every non-alphanumeric character to `_`,
/// e.g. `lost items` -> `lost_items`, `day-laborers` -> `day_laborers`.
///
/// The shared need-to-key contract so sibling chips keyed by different
/// needs never collide: [PatronageChip] derives
/// `patronage_chip_<fragment>` and the category detail screen (Task 12)
/// derives `need_chip_<fragment>` from it.
String needKeyFragment(String need) {
  return need.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
}

/// A chip for one patronage need: the label is the need, tapping it opens
/// the search screen seeded with that need (`/search` with `extra` holding
/// the need text — the search route forwards `extra` as the initial query).
class PatronageChip extends StatelessWidget {
  const PatronageChip({required this.patronage, super.key});

  /// The patronage (need + category) to render.
  final SaintPatronage patronage;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      // Key contract (fix round 1): with no explicit [key], the chip
      // surface carries `Key('patronage_chip_<need-sanitized>')` (see
      // [needKeyFragment]) so sibling chips never collide; an
      // explicit key is applied to the PatronageChip widget itself via
      // [super.key] instead.
      key: key == null
          ? Key('patronage_chip_${needKeyFragment(patronage.need)}')
          : null,
      label: Text(patronage.need),
      onPressed: () => context.push('/search', extra: patronage.need),
    );
  }
}
