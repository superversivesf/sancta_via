import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saint_data/saint_data.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';

import '../../providers/saint_providers.dart';
import '../../widgets/category_card.dart';
import '../../widgets/liturgical_day_card.dart';
import '../../widgets/saint_card.dart';

/// The saints home screen (Task 11): today's saints, featured saints,
/// the category grid with counts, and today's liturgical celebration, in
/// that order. Failed repository loads surface a keyed error card with a
/// retry affordance.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LiturgicalDayData? liturgicalDay = ref.watch(
      currentLiturgicalDayProvider,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saints'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search saints',
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Spec §8 order: the liturgical celebration card leads.
              LiturgicalDayCard(day: liturgicalDay),
              const SizedBox(height: 24),
              _HomeSection(
                key: const Key('today_saints_section'),
                title: "Today's Saints",
                child: _buildTodaySection(context, ref),
              ),
              const SizedBox(height: 24),
              _HomeSection(
                key: const Key('featured_section'),
                title: 'Featured Saints',
                child: _buildFeaturedSection(context, ref),
              ),
              const SizedBox(height: 24),
              _HomeSection(
                title: 'Browse by Need',
                child: _buildCategorySection(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Today's feast-day saints: cards when populated, an empty state when
  /// nobody celebrates today, a retry card when the load failed.
  Widget _buildTodaySection(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Saint>> today = ref.watch(saintsTodayProvider);
    return today.when(
      loading: () => const _SectionSpinner(),
      error: (Object error, StackTrace stackTrace) => _ErrorCard(
        stateKey: const Key('load_error_state_today'),
        onRetry: () => ref.invalidate(saintsTodayProvider),
      ),
      data: (List<Saint> saints) {
        if (saints.isEmpty) {
          return const Padding(
            key: Key('today_empty_state'),
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No saints on the calendar today.'),
          );
        }
        return Column(
          children: <Widget>[
            for (final Saint saint in saints) ...<Widget>[
              SaintCard(saint: saint, key: Key('saint_card_${saint.slug}')),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }

  /// The featured saints carousel.
  Widget _buildFeaturedSection(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Saint>> featured = ref.watch(featuredSaintsProvider);
    return featured.when(
      loading: () => const _SectionSpinner(),
      error: (Object error, StackTrace stackTrace) => _ErrorCard(
        stateKey: const Key('load_error_state_featured'),
        onRetry: () => ref.invalidate(featuredSaintsProvider),
      ),
      data: (List<Saint> saints) {
        if (saints.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No featured saints yet.'),
          );
        }
        return SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: saints.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: 12),
            itemBuilder: (BuildContext context, int index) => SizedBox(
              width: 280,
              child: SaintCard(
                saint: saints[index],
                key: Key('saint_card_${saints[index].slug}'),
              ),
            ),
          ),
        );
      },
    );
  }

  /// The patronage category grid: all 10 categories, each with its saint
  /// count (0 when the category has none yet).
  Widget _buildCategorySection(BuildContext context, WidgetRef ref) {
    final AsyncValue<Map<SaintCategory, int>> counts = ref.watch(
      categoryCountsProvider,
    );
    return counts.when(
      loading: () => const _SectionSpinner(),
      error: (Object error, StackTrace stackTrace) => _ErrorCard(
        stateKey: const Key('load_error_state_categories'),
        onRetry: () => ref.invalidate(categoryCountsProvider),
      ),
      data: (Map<SaintCategory, int> counts) {
        return GridView(
          // Fixed tile height (mainAxisExtent) keeps the two-line category
          // labels from overflowing on any device width.
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            mainAxisExtent: 130,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: <Widget>[
            for (final SaintCategory category in SaintCategory.values)
              CategoryCard(category: category, count: counts[category] ?? 0),
          ],
        );
      },
    );
  }
}

/// A keyed error card with a retry button, shown when a provider fails.
/// Each section passes [stateKey] (`load_error_state_<section>`) so keyed
/// lookups target one section's error state.
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.stateKey, required this.onRetry});

  /// Key for the rendered card, e.g. `Key('load_error_state_today')`.
  final Key stateKey;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: stateKey,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            const Icon(Icons.error_outline, size: 32),
            const SizedBox(height: 8),
            Text(
              'Could not load saints.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// Centered spinner used for a section's loading state.
class _SectionSpinner extends StatelessWidget {
  const _SectionSpinner();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// A titled section block; [key] identifies the section for tests.
class _HomeSection extends StatelessWidget {
  const _HomeSection({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
