import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saint_data/saint_data.dart';

import '../../models/saint_app_settings.dart';
import '../../providers/saint_app_settings_provider.dart';
import '../../providers/saint_providers.dart';
import '../../widgets/load_error_card.dart';
import '../../widgets/saint_image.dart';
import '../../widgets/section_spinner.dart';

/// The favorites screen (Task 15): two sections over the Task-9 settings
/// provider's slug lists, both resolving saints through the Task-10
/// `saintBySlugProvider` per slug.
///
/// - `favorites_section` — one row per favorite slug, in stored (added)
///   order. Each row tappable to `/saints/<slug>` (SaintCard precedent)
///   and carries a remove button: tapping it calls
///   [SaintAppSettingsNotifier.toggleFavorite], and because the settings
///   provider is synchronous state the row disappears from the section on
///   the next frame (persistence itself is the Task-9 provider's job).
/// - `recents_section` — one row per recent slug, most-recent-first (the
///   stored list order). Rows navigate only; unfavoriting lives in the
///   favorites section.
///
/// Unknown slugs (a settings state carrying a slug the current database
/// no longer resolves — possible only across data-asset resets) are IGNORED
/// gracefully: their lookup completes `AsyncData(null)` and the row is
/// filtered out; the saint detail screen handles its own load errors.
///
/// State keys per section: the section wrapper (`favorites_section` /
/// `recents_section`), the empty state (`favorites_empty_state` /
/// `recents_empty_state`), the loading spinner (`<section>_loading_state`),
/// and the shared LoadErrorCard (`favorites_error_state` — the Task-15
/// brief pin — and `recents_error_state`, the house `<section>_error_state`
/// convention since Task 12). Any failed slug lookup renders the section's
/// error card; retry invalidates the whole `saintBySlugProvider` family.
/// Row keys: `favorite_row_<slug>` / `recent_row_<slug>`, with the remove
/// button keyed `favorite_remove_<slug>`.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Synchronous settings state (Task-9): the slug lists are always ready
    // to read; the per-slug saint lookups watch below stay reactive to both
    // the lists and the database-backed providers.
    final SaintAppSettings settings = ref.watch(saintAppSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _SectionHeader('Favorites'),
              _SlugSection(
                slugs: settings.favoriteSlugs,
                sectionKey: const Key('favorites_section'),
                emptyStateKey: const Key('favorites_empty_state'),
                loadingStateKey: const Key('favorites_loading_state'),
                errorStateKey: const Key('favorites_error_state'),
                emptyText: 'No favorites yet.',
                rowKeyPrefix: 'favorite_row_',
                removable: true,
              ),
              const _SectionHeader('Recently Viewed'),
              _SlugSection(
                slugs: settings.recentSlugs,
                sectionKey: const Key('recents_section'),
                emptyStateKey: const Key('recents_empty_state'),
                loadingStateKey: const Key('recents_loading_state'),
                errorStateKey: const Key('recents_error_state'),
                emptyText: 'No recently viewed saints.',
                rowKeyPrefix: 'recent_row_',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small section label above a [_SlugSection].
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// One keyed section of saint rows resolved from [slugs] through
/// `saintBySlugProvider(slug)` (watched per slug, so list edits and
/// database re-loads both rebuild the section).
class _SlugSection extends ConsumerWidget {
  const _SlugSection({
    required this.slugs,
    required this.sectionKey,
    required this.emptyStateKey,
    required this.loadingStateKey,
    required this.errorStateKey,
    required this.emptyText,
    required this.rowKeyPrefix,
    this.removable = false,
  });

  /// The settings slugs this section renders (favorites: added order;
  /// recents: most-recent-first, both stored order).
  final List<String> slugs;

  final Key sectionKey;
  final Key emptyStateKey;
  final Key loadingStateKey;
  final Key errorStateKey;

  /// Message shown by the keyed empty state.
  final String emptyText;

  /// Row key prefix producing `Key('<prefix><slug>')`.
  final String rowKeyPrefix;

  /// Favorites rows carry a remove button (`Key('favorite_remove_<slug>')`)
  /// that unfavorites the slug immediately; recents rows do not.
  final bool removable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (slugs.isEmpty) {
      return _buildState(
        sectionKey,
        Padding(
          key: emptyStateKey,
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(child: Text(emptyText)),
        ),
      );
    }

    final List<AsyncValue<Saint?>> lookups = <AsyncValue<Saint?>>[
      for (final String slug in slugs) ref.watch(saintBySlugProvider(slug)),
    ];

    // Any failed lookup renders the shared error card; retry invalidates
    // the whole family so every watched slug re-queries.
    for (final AsyncValue<Saint?> lookup in lookups) {
      if (lookup.hasError) {
        return _buildState(
          sectionKey,
          LoadErrorCard(
            stateKey: errorStateKey,
            onRetry: () => ref.invalidate(saintBySlugProvider),
          ),
        );
      }
    }
    // Any still-resolving lookup holds the section on its spinner (the
    // prewarmed test harness renders AsyncData synchronously instead).
    for (final AsyncValue<Saint?> lookup in lookups) {
      if (lookup.isLoading) {
        return _buildState(sectionKey, SectionSpinner(key: loadingStateKey));
      }
    }

    // Missing-saint filtering: a slug whose lookup resolved to null (the
    // saint left the database — settings state can only drift from it
    // across data-asset resets) is IGNORED instead of rendering a broken
    // row; the remaining saints keep their stored order.
    final List<Saint> saints = <Saint>[
      for (var i = 0; i < slugs.length; i++)
        if (lookups[i].valueOrNull case final Saint? saint when saint != null)
          saint,
    ];

    return _buildState(
      sectionKey,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < saints.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 8),
            _SaintRow(
              key: Key('$rowKeyPrefix${saints[i].slug}'),
              saint: saints[i],
              trailing: removable
                  ? IconButton(
                      key: Key('favorite_remove_${saints[i].slug}'),
                      icon: const Icon(Icons.favorite),
                      color: Theme.of(context).colorScheme.primary,
                      tooltip: 'Remove from favorites',
                      onPressed: () => ref
                          .read(saintAppSettingsProvider.notifier)
                          .toggleFavorite(saints[i].slug),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  /// The keyed section wrapper around one section state (empty / error /
  /// loading / rows) — the wrapper always renders so keyed lookups find
  /// the section in every state.
  Widget _buildState(Key key, Widget state) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[state],
    );
  }
}

/// A SaintCard-like list-row for one resolved saint: thumb, name, first
/// patronage, an optional trailing widget. The row body tappable,
/// navigating to `/saints/<slug>` (same destination as SaintCard) — a
/// trailing [IconButton] sits OUTSIDE the InkWell, so removing never
/// navigates.
class _SaintRow extends StatelessWidget {
  const _SaintRow({required this.saint, this.trailing, super.key});

  /// The saint this row renders (patronages hydrated by the provider).
  final Saint saint;

  /// Optional trailing widget (the favorites remove button).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final SaintPatronage? firstPatronage = saint.patronages.isNotEmpty
        ? saint.patronages.first
        : null;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/saints/${saint.slug}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              SaintImage(
                saint: saint,
                width: 56,
                height: 112,
                borderRadius: BorderRadius.circular(8),
                showPlaceholderIfMissing: false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      saint.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (firstPatronage != null)
                      Text(
                        '${firstPatronage.need} · '
                        '${firstPatronage.category.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
