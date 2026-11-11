import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saint_data/saint_data.dart';

import '../../providers/saint_providers.dart';
import '../../widgets/category_card.dart';
import '../../widgets/load_error_card.dart';
import '../../widgets/section_spinner.dart';

/// The category browse screen (Task 12): a grid of all 10 patronage
/// categories, each tile carrying its saint count from
/// [categoryCountsProvider]. Failed repository loads surface a keyed error
/// card with a retry affordance (`Key('categories_error_state')`).
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Map<SaintCategory, int>> countsAsync = ref.watch(
      categoryCountsProvider,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: SafeArea(
        top: false,
        child: countsAsync.when(
          loading: () => const SectionSpinner(),
          error: (Object error, StackTrace stackTrace) => LoadErrorCard(
            stateKey: const Key('categories_error_state'),
            onRetry: () => ref.invalidate(categoryCountsProvider),
          ),
          data: (Map<SaintCategory, int> counts) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: GridView(
                // Same delegate as the home category grid: fixed tile
                // height keeps two-line labels from overflowing.
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
                    CategoryCard(
                      key: Key('category_card_${category.name}'),
                      category: category,
                      // Zero-count categories still render (all 10 tiles).
                      count: counts[category] ?? 0,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
