import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:saint_data/saint_data.dart';

/// A chip for one patronage need: the label is the need, tapping it opens
/// the search screen seeded with that need (`/search` with `extra` holding
/// the need text — the search route forwards `extra` as the initial query).
class PatronageChip extends StatelessWidget {
  const PatronageChip({required this.patronage})
    : super(key: const Key('patronage_chip'));

  /// The patronage (need + category) to render.
  final SaintPatronage patronage;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(patronage.need),
      onPressed: () => context.push('/search', extra: patronage.need),
    );
  }
}
