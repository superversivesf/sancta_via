import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saint_data/saint_data.dart';

import '../../providers/saint_providers.dart';
import '../../widgets/load_error_card.dart';
import '../../widgets/patronage_chip.dart' show needKeyFragment;
import '../../widgets/saint_card.dart';
import '../../widgets/section_spinner.dart';

/// The category detail screen (Task 12): the saints serving the category
/// (via [saintsByCategoryProvider]) plus need anchor chips with counts
/// (via [needsForCategoryProvider]) that push `/search` seeded with the
/// need text — the same `extra` forwarding contract as PatronageChip.
///
/// An unknown category id (unparseable by [SaintCategory.tryParse]) renders
/// the pinned fallback in the Task-8 route-error style: a message keyed
/// `Key('category_not_found')` with a back-home affordance.
class CategoryDetailScreen extends ConsumerWidget {
  const CategoryDetailScreen({required this.categoryId, super.key});

  /// The route param (`/categories/:category`).
  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SaintCategory? category = SaintCategory.tryParse(categoryId);
    if (category == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Category Not Found')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.error_outline, size: 64),
              const SizedBox(height: 16),
              Text(
                'Category not found.',
                key: const Key('category_not_found'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      );
    }

    final AsyncValue<List<Saint>> saintsAsync = ref.watch(
      saintsByCategoryProvider(category),
    );
    final AsyncValue<Map<String, int>> needsAsync = ref.watch(
      needsForCategoryProvider(category),
    );
    return Scaffold(
      appBar: AppBar(title: Text(category.label)),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _CategorySection(
                key: const Key('category_saints_section'),
                title: 'Saints',
                child: _buildSaints(context, ref, saintsAsync, category),
              ),
              const SizedBox(height: 24),
              _CategorySection(
                key: const Key('category_needs_section'),
                title: 'Common Needs',
                child: _buildNeeds(context, ref, needsAsync, category),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The saints serving the category: cards when populated, an empty state
  /// when the category has no saints yet, a retry card on load failure.
  Widget _buildSaints(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Saint>> saintsAsync,
    SaintCategory category,
  ) {
    return saintsAsync.when(
      loading: () => const SectionSpinner(),
      error: (Object error, StackTrace stackTrace) => LoadErrorCard(
        stateKey: const Key('category_saints_error_state'),
        onRetry: () => ref.invalidate(saintsByCategoryProvider(category)),
      ),
      data: (List<Saint> saints) {
        if (saints.isEmpty) {
          return const Padding(
            key: Key('category_empty_state'),
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No saints in this category yet.'),
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

  /// The need anchor chips: need + saint count, ordered count-desc by the
  /// repository. Each chip keys `need_chip_<needKeyFragment(need)>` so
  /// sibling chips never collide, and pushes `/search` with the need text
  /// as `extra` (the search route forwards it as the initial query — Task
  /// 14 wires that screen).
  Widget _buildNeeds(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Map<String, int>> needsAsync,
    SaintCategory category,
  ) {
    return needsAsync.when(
      loading: () => const SectionSpinner(),
      error: (Object error, StackTrace stackTrace) => LoadErrorCard(
        stateKey: const Key('category_needs_error_state'),
        onRetry: () => ref.invalidate(needsForCategoryProvider(category)),
      ),
      data: (Map<String, int> needs) {
        if (needs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No common needs yet.'),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final MapEntry<String, int> entry in needs.entries)
              ActionChip(
                key: Key('need_chip_${needKeyFragment(entry.key)}'),
                label: Text('${entry.key} (${entry.value})'),
                onPressed: () => context.push('/search', extra: entry.key),
              ),
          ],
        );
      },
    );
  }
}

/// A titled section block; [key] identifies the section for tests.
class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.title, required this.child, super.key});

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
