import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart'
    show ContentPack, PackFamily;
import 'package:sancta_via_devotionals/providers/today_providers.dart'
    show TodayItem;

/// Icons keyed by the pack's family: routine anchors get a time-of-day
/// glyph, commitments a flag, novenas a repeat glyph; every family is an
/// engine enum value, so the switch is exhaustive.
IconData _iconFor(TodayItem item) {
  final ContentPack? pack = item.pack;
  if (pack == null) {
    // A calendar-only item: a coming feast, not a devotional program.
    return Icons.church;
  }
  return switch (pack.family) {
    PackFamily.commitment => Icons.flag,
    PackFamily.novena => Icons.event_repeat,
    PackFamily.office => Icons.menu_book,
    PackFamily.routine => Icons.schedule,
    PackFamily.chaplet => Icons.blur_circular,
  };
}

/// One tile of a [TodayItem] on the Today screen.
///
/// Renders the item's title with a family icon and, where the engine's
/// resolution carries one, its position badge (a commitment's ordinal label
/// or a novena's day index); the trailing chip shows the anchor instant —
/// a tile's wall-clock time, or a feast's calendar date. A tap deep-links
/// into the session player (`context.go`, the day-locked link the assembly
/// built); a feast has no link and stays inert.
class TodayItemTile extends StatelessWidget {
  /// Creates a tile for [item].
  const TodayItemTile({required this.item, super.key});

  /// The assembled day's entry to render.
  final TodayItem item;

  /// The session player deep link, or null when the item cannot navigate.
  String? get _deepLink => item.deepLink;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? ordinal = item.ordinalLabel;
    final int? dayIndex = item.resolution?.dayIndex;
    final String? badge =
        ordinal ?? (dayIndex == null ? null : 'Day $dayIndex');
    final DateTime? anchor = item.anchor;
    final bool isFeast = item.pack == null;

    return ListTile(
      key: ValueKey<String>(
        'today_item_${item.pack?.id ?? 'feast:${item.title}'}',
      ),
      leading: Icon(_iconFor(item), color: theme.colorScheme.primary),
      title: Row(
        children: <Widget>[
          Expanded(child: Text(item.title)),
          if (badge != null) _ItemBadge(label: badge),
        ],
      ),
      trailing: anchor == null
          ? const Icon(Icons.chevron_right)
          : _ItemBadge(
              label: isFeast
                  ? MaterialLocalizations.of(context).formatMediumDate(anchor)
                  : MaterialLocalizations.of(
                      context,
                    ).formatTimeOfDay(TimeOfDay.fromDateTime(anchor)),
              solid: true,
            ),
      onTap: isFeast
          ? null
          : _deepLink == null
          ? null
          : () => context.go(_deepLink!),
    );
  }
}

/// The tile's small rounded label (a [TodayItemTile] position badge or
/// anchor chip).
class _ItemBadge extends StatelessWidget {
  const _ItemBadge({required this.label, this.solid = false});

  final String label;

  /// Whether the badge is filled (the anchor-time chip) or outlined (a
  /// position badge).
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: solid
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surface,
        border: Border.all(
          color: solid
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: solid
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
