import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:saint_data/saint_data.dart';

/// Icons for the 10 patronage categories (verbatim from the plan).
const Map<SaintCategory, IconData> categoryIcons = <SaintCategory, IconData>{
  SaintCategory.everyday: Icons.home,
  SaintCategory.illness: Icons.healing,
  SaintCategory.jobs: Icons.work,
  SaintCategory.travel: Icons.flight,
  SaintCategory.persecution: Icons.shield,
  SaintCategory.spiritual: Icons.church,
  SaintCategory.military: Icons.shield_moon,
  SaintCategory.family: Icons.family_restroom,
  SaintCategory.nature: Icons.pets,
  SaintCategory.special: Icons.volunteer_activism,
};

/// A tile in the category grid: icon + label + saint count, tappable to
/// `/categories/<id>`.
class CategoryCard extends StatelessWidget {
  const CategoryCard({required this.category, required this.count, super.key});

  /// The category to render.
  final SaintCategory category;

  /// How many saints serve needs in this category (0 when none yet).
  final int count;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/categories/${category.name}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                categoryIcons[category],
                size: 28,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                category.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '$count ${count == 1 ? 'saint' : 'saints'}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
