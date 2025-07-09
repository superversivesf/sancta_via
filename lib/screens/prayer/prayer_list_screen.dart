import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import '../../models/prayer_metadata.dart';
import '../../providers/prayer_providers.dart';
import '../../widgets/prayer_card.dart';
import 'prayer_detail_screen.dart';

class PrayerListScreen extends ConsumerWidget {
  final String title;
  final String? categoryId;
  final String? groupId;
  final bool showFavorites;
  final bool showRecent;

  const PrayerListScreen({
    required this.title, super.key,
    this.categoryId,
    this.groupId,
    this.showFavorites = false,
    this.showRecent = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get liturgical color for theming
    final currentColor = ref.watch(currentLiturgicalColorProvider);
    final colorIntensity = ref.watch(colorIntensityProvider);
    final liturgicalColor = currentColor != null 
        ? LiturgicalColor.fromString(currentColor)
        : null;
    final themeColor = liturgicalColor?.toFlutterColor(colorIntensity);

    // Get prayers based on the type of list
    final prayersAsync = _getPrayersProvider(ref);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: themeColor?.withValues(alpha: 0.1),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context, ref),
          ),
        ],
      ),
      body: prayersAsync.when(
        data: (prayers) {
          if (prayers.isEmpty) {
            return _buildEmptyState(context, themeColor);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: prayers.length,
            itemBuilder: (context, index) {
              final prayer = prayers[index];
              return PrayerCard(
                prayer: prayer,
                onTap: () => _navigateToPrayer(context, prayer.id),
                themeColor: themeColor,
              );
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
                'Error loading prayers',
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
                onPressed: () => _retryLoadingPrayers(ref),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Determine which provider to use based on the screen type
  AsyncValue<List<PrayerMetadata>> _getPrayersProvider(WidgetRef ref) {
    if (showFavorites) {
      return ref.watch(favoritePrayersProvider);
    } else if (showRecent) {
      return ref.watch(recentPrayersProvider);
    } else if (categoryId != null) {
      return ref.watch(prayersByCategoryProvider(categoryId!));
    } else if (groupId != null) {
      return ref.watch(prayersByGroupProvider(groupId!));
    } else {
      return ref.watch(filteredPrayersProvider);
    }
  }

  // Retry loading prayers by invalidating the correct provider
  void _retryLoadingPrayers(WidgetRef ref) {
    if (showFavorites) {
      ref.invalidate(favoritePrayersProvider);
    } else if (showRecent) {
      ref.invalidate(recentPrayersProvider);
    } else if (categoryId != null) {
      ref.invalidate(prayersByCategoryProvider(categoryId!));
    } else if (groupId != null) {
      ref.invalidate(prayersByGroupProvider(groupId!));
    } else {
      ref.invalidate(filteredPrayersProvider);
    }
  }

  Widget _buildEmptyState(BuildContext context, Color? themeColor) {
    String message;
    IconData icon;

    if (showFavorites) {
      message = 'No favorite prayers yet.\nStart adding prayers to your favorites!';
      icon = Icons.favorite_border;
    } else if (showRecent) {
      message = 'No recent prayers.\nStart reading prayers to see them here!';
      icon = Icons.history;
    } else {
      message = 'No prayers found.\nTry adjusting your filters.';
      icon = Icons.search_off;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: themeColor?.withValues(alpha: 0.6) ?? 
                     Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              message,
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

  void _navigateToPrayer(BuildContext context, String prayerId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PrayerDetailScreen(prayerId: prayerId),
      ),
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter Prayers',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final selectedTags = ref.watch(selectedTagsProvider);
                      final availableTags = ref.watch(availableTagsProvider);
                      final showFavoritesOnly = ref.watch(showFavoritesOnlyProvider);

                      return ListView(
                        controller: scrollController,
                        children: [
                          // Favorites toggle
                          SwitchListTile(
                            title: const Text('Show favorites only'),
                            value: showFavoritesOnly,
                            onChanged: (value) {
                              ref.read(showFavoritesOnlyProvider.notifier).state = value;
                            },
                          ),
                          const Divider(),
                          
                          // Tags section
                          Text(
                            'Filter by Tags',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: availableTags.map((tag) {
                              final isSelected = selectedTags.contains(tag);
                              return FilterChip(
                                label: Text(tag),
                                selected: isSelected,
                                onSelected: (selected) {
                                  ref.read(selectedTagsProvider.notifier).toggleTag(tag);
                                },
                              );
                            }).toList(),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Clear filters button
                          if (selectedTags.isNotEmpty || showFavoritesOnly)
                            ElevatedButton(
                              onPressed: () {
                                ref.read(selectedTagsProvider.notifier).clearTags();
                                ref.read(showFavoritesOnlyProvider.notifier).state = false;
                              },
                              child: const Text('Clear All Filters'),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}