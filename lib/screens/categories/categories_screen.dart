import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import '../../models/prayer_category_group.dart';
import '../../providers/prayer_providers.dart';
import '../prayer/prayer_list_screen.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryGroupsAsync = ref.watch(prayerCategoryGroupsProvider);
    
    // Get liturgical color for theming
    final currentColor = ref.watch(currentLiturgicalColorProvider);
    final colorIntensity = ref.watch(colorIntensityProvider);
    final liturgicalColor = currentColor != null 
        ? LiturgicalColor.fromString(currentColor)
        : null;
    final themeColor = liturgicalColor?.toFlutterColor(colorIntensity);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Categories'),
        backgroundColor: themeColor?.withValues(alpha: 0.1),
      ),
      body: categoryGroupsAsync.when(
        data: (categoryGroups) {
          if (categoryGroups.isEmpty) {
            return _buildEmptyState(context, themeColor);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categoryGroups.length + 2, // +2 for favorites and recent
            itemBuilder: (context, index) {
              // Special items at the top
              if (index == 0) {
                return _buildSpecialCard(
                  context,
                  'Favorites',
                  'Your saved prayers',
                  Icons.favorite,
                  themeColor,
                  () => _navigateToFavorites(context),
                );
              }
              
              if (index == 1) {
                return _buildSpecialCard(
                  context,
                  'Recent',
                  'Recently viewed prayers',
                  Icons.history,
                  themeColor,
                  () => _navigateToRecent(context),
                );
              }

              // Category groups
              final group = categoryGroups[index - 2];
              return _buildCategoryGroupCard(context, group, themeColor);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading categories',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(prayerCategoryGroupsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color? themeColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: themeColor?.withValues(alpha: 0.6) ?? 
                     Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No prayer categories found.\nCheck your prayer data.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecialCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color? themeColor,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: themeColor != null ? Border.all(
              color: themeColor.withValues(alpha: 0.2),
              width: 1,
            ) : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: themeColor?.withValues(alpha: 0.1) ?? 
                           Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: themeColor ?? Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: themeColor?.withValues(alpha: 0.7) ?? 
                         Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGroupCard(
    BuildContext context,
    PrayerCategoryGroup group,
    Color? themeColor,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToGroup(context, group),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: themeColor != null ? Border.all(
              color: themeColor.withValues(alpha: 0.2),
              width: 1,
            ) : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: themeColor?.withValues(alpha: 0.1) ?? 
                           Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIconFromString(group.icon),
                    size: 28,
                    color: themeColor ?? Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        group.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: themeColor?.withValues(alpha: 0.7) ?? 
                         Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconFromString(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'favorite':
      case 'heart':
        return Icons.favorite;
      case 'prayer':
      case 'hands':
        return Icons.favorite_border;
      case 'morning':
      case 'sun':
        return Icons.wb_sunny;
      case 'evening':
      case 'moon':
        return Icons.brightness_3;
      case 'meal':
      case 'food':
        return Icons.restaurant;
      case 'travel':
      case 'journey':
        return Icons.flight;
      case 'special':
      case 'celebration':
        return Icons.star;
      case 'marian':
      case 'mary':
        return Icons.person;
      case 'saints':
      case 'saint':
        return Icons.people;
      case 'liturgical':
      case 'church':
        return Icons.home;
      default:
        return Icons.category;
    }
  }

  void _navigateToFavorites(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PrayerListScreen(
          title: 'Favorite Prayers',
          showFavorites: true,
        ),
      ),
    );
  }

  void _navigateToRecent(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PrayerListScreen(
          title: 'Recent Prayers',
          showRecent: true,
        ),
      ),
    );
  }

  void _navigateToGroup(BuildContext context, PrayerCategoryGroup group) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PrayerListScreen(
          title: group.title,
          groupId: group.id,
        ),
      ),
    );
  }
}