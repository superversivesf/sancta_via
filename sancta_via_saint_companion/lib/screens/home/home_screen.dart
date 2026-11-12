import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saint_data/saint_data.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';

import '../../providers/saint_providers.dart';
import '../../widgets/category_card.dart';
import '../../widgets/liturgical_day_card.dart';
import '../../widgets/load_error_card.dart';
import '../../widgets/saint_card.dart';
import '../../widgets/section_spinner.dart';

/// The saints home screen (Task 11): today's saints, featured saints,
/// the category grid with counts, and today's liturgical celebration, in
/// that order. Failed repository loads surface a keyed error card with a
/// retry affordance. The AppBar keeps the search action plus an overflow
/// menu that reaches the spec §8 screens (/categories, /favorites,
/// /settings).
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
          // Spec §8 screens (/categories, /favorites, /settings) are
          // reachable through this overflow menu (final-review fix wave:
          // they had no navigation at all); the search action stays.
          PopupMenuButton<String>(
            key: const Key('nav_menu'),
            icon: const Icon(Icons.more_vert),
            tooltip: 'More',
            onSelected: (String route) => context.push(route),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                key: Key('nav_menu_browse'),
                value: '/categories',
                child: Text('Browse'),
              ),
              const PopupMenuItem<String>(
                key: Key('nav_menu_favorites'),
                value: '/favorites',
                child: Text('Favorites'),
              ),
              const PopupMenuItem<String>(
                key: Key('nav_menu_settings'),
                value: '/settings',
                child: Text('Settings'),
              ),
            ],
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
      loading: () => const SectionSpinner(),
      error: (Object error, StackTrace stackTrace) => LoadErrorCard(
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
      loading: () => const SectionSpinner(),
      error: (Object error, StackTrace stackTrace) => LoadErrorCard(
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
      loading: () => const SectionSpinner(),
      error: (Object error, StackTrace stackTrace) => LoadErrorCard(
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
