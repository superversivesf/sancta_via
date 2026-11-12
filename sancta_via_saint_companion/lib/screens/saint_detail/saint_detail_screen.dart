import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saint_data/saint_data.dart';

import '../../models/saint_app_settings.dart';
import '../../providers/saint_app_settings_provider.dart';
import '../../providers/saint_providers.dart';
import '../../utils/logger.dart';
import '../../widgets/load_error_card.dart';
import '../../widgets/patronage_chip.dart';
import '../../widgets/saint_image.dart';
import '../../widgets/section_spinner.dart';

/// Human feast-day label for a stored `MM-DD` key, e.g. `03-05` → `March 5`.
///
/// Inline per the Task 13 brief (no coupling to the feast-day lookup
/// service). Returns null for unknown or malformed keys so no feast line
/// renders for `unknown` feast days.
String? _formatFeastDay(String feastDay) {
  final List<String> parts = feastDay.split('-');
  if (parts.length != 2) {
    return null;
  }
  final int? month = int.tryParse(parts[0]);
  final int? day = int.tryParse(parts[1]);
  if (month == null ||
      day == null ||
      month < 1 ||
      month > 12 ||
      day < 1 ||
      day > 31) {
    return null;
  }
  return DateFormat('MMMM d').format(DateTime(2000, month, day));
}

/// The saint detail screen (Task 13): header thumb (with attribution line
/// when shipped), feast day, canonization status, patronage chips (each
/// pushing `/search` seeded with its need), bio, a copyable prayer card,
/// and the record's source URLs as launch-less tiles.
///
/// An unknown slug renders the Task-12 `category_not_found` fallback style:
/// a message keyed `Key('saint_not_found')` with a back-home affordance.
/// Opening a saint records the visit ([SaintAppSettingsNotifier.addRecent])
/// and the AppBar favorite toggle flips
/// [saintAppSettingsProvider.toggleFavorite].
class SaintDetailScreen extends ConsumerStatefulWidget {
  const SaintDetailScreen({required this.slug, super.key});

  /// The route param (`/saints/:slug`).
  final String slug;

  @override
  ConsumerState<SaintDetailScreen> createState() => _SaintDetailScreenState();
}

class _SaintDetailScreenState extends ConsumerState<SaintDetailScreen> {
  @override
  void initState() {
    super.initState();
    // The visit is recorded when the screen opens — for RESOLVED saints
    // only. Riverpod forbids mutating a provider inside a build-phase
    // life-cycle, so this runs deferred (the framework's own suggested
    // remedy); it resolves the saint OUTSIDE the widget tree and re-checks
    // [mounted] before and after the await. A route popped before the
    // deferred turn (or before resolution) never touches `ref` again —
    // riverpod's `_assertNotDisposed` raises a StateError from the timer
    // callback otherwise — and an unknown slug never enters recents.
    unawaited(
      Future<void>(() async {
        if (!mounted) {
          return;
        }
        Saint? saint;
        try {
          saint = await ref.read(saintBySlugProvider(widget.slug).future);
        } on Object catch (error) {
          // A failed load resolves through the keyed error card instead
          // (`detail_error_state`); the failure itself is already logged by
          // the repository/load layer (spec §9: safe defaults, no crash).
          AppLogger.debug(
            'Visit not recorded; saint lookup failed: $error',
            'SAINT_DETAIL',
          );
          return;
        }
        if (!mounted || saint == null) {
          return;
        }
        ref.read(saintAppSettingsProvider.notifier).addRecent(widget.slug);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Saint?> saintAsync = ref.watch(
      saintBySlugProvider(widget.slug),
    );
    final Saint? saint = saintAsync.asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(saint?.name ?? 'Saint Detail'),
        actions: saint == null ? null : <Widget>[_FavoriteToggle(saint: saint)],
      ),
      body: SafeArea(
        top: false,
        child: saintAsync.when(
          loading: () => const SectionSpinner(),
          error: (Object error, StackTrace stackTrace) => LoadErrorCard(
            stateKey: const Key('detail_error_state'),
            onRetry: () => ref.invalidate(saintBySlugProvider(widget.slug)),
          ),
          data: (Saint? saint) => saint == null
              ? _buildNotFound(context)
              : _buildDetail(context, saint),
        ),
      ),
    );
  }

  /// Unparseable-slug fallback, mirroring the Task-12 `category_not_found`
  /// style: error icon, keyed message, back-home affordance.
  Widget _buildNotFound(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.error_outline, size: 64),
          const SizedBox(height: 16),
          Text(
            'Saint not found.',
            key: const Key('saint_not_found'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetail(BuildContext context, Saint saint) {
    final String? feastLabel = _formatFeastDay(saint.feastDay);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SaintImage(
            saint: saint,
            width: double.infinity,
            height: 220,
            borderRadius: BorderRadius.circular(12),
          ),
          // Attribution renders only when the record ships one (spec §12:
          // Wikimedia attribution is a license obligation, so it is never
          // silently dropped when present).
          if (saint.imageAttribution != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              saint.imageAttribution!,
              key: const Key('image_attribution'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (feastLabel != null)
            Text(
              feastLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          if (saint.canonized != null)
            Text(
              'Canonized: ${saint.canonized}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          if (saint.patronages.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                // With no explicit key, each chip's surface carries
                // `Key('patronage_chip_<needKeyFragment(need)>')` — the
                // Task-11 chip-key contract, single-sourced in
                // patronage_chip.dart.
                for (final SaintPatronage patronage in saint.patronages)
                  PatronageChip(patronage: patronage),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(saint.bio, style: Theme.of(context).textTheme.bodyMedium),
          _buildPrayerCard(context, saint),
          _buildSources(context, saint),
        ],
      ),
    );
  }

  /// The collect-style prayer card with a copy-to-clipboard affordance.
  /// Absent when the record ships no prayer.
  Widget _buildPrayerCard(BuildContext context, Saint saint) {
    final SaintPrayer? prayer = saint.prayer;
    if (prayer == null) {
      return const SizedBox.shrink();
    }
    return Card(
      key: const Key('prayer_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Prayer',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(prayer.text, style: Theme.of(context).textTheme.bodyMedium),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Copy prayer',
                icon: const Icon(Icons.copy),
                onPressed: () {
                  unawaited(
                    Clipboard.setData(ClipboardData(text: prayer.text)),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Prayer copied to clipboard.'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The record's source URLs as PLAIN launch-less tiles (spec §8: URL text
  /// only — this app carries no url_launcher dependency). `getBySlug` never
  /// populates `sources` today (the committed schema stores no sources
  /// table), so this section is dormant until a sources table ships; kept
  /// so the model field is honored when it does.
  Widget _buildSources(BuildContext context, Saint saint) {
    if (saint.sources.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SizedBox(height: 16),
        Text(
          'Sources',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        for (final String url in saint.sources)
          ListTile(
            title: Text(url, style: Theme.of(context).textTheme.bodyMedium),
          ),
      ],
    );
  }
}

/// The AppBar favorite toggle: filled heart when the saint is favorited,
/// outline otherwise, writing through [saintAppSettingsProvider].
class _FavoriteToggle extends ConsumerWidget {
  const _FavoriteToggle({required this.saint});

  final Saint saint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isFavorite = ref.watch(
      saintAppSettingsProvider.select(
        (SaintAppSettings settings) => settings.isFavorite(saint.slug),
      ),
    );
    return IconButton(
      key: const Key('favorite_toggle'),
      tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
      icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
      onPressed: () {
        final SaintAppSettingsNotifier notifier = ref.read(
          saintAppSettingsProvider.notifier,
        );
        unawaited(notifier.toggleFavorite(saint.slug));
        // Spec §8: the favorite toggle records a recents visit too. Opening
        // the saint already recorded it (deduped, still front), so this
        // only guarantees the toggle path on its own.
        unawaited(notifier.addRecent(saint.slug));
      },
    );
  }
}
