import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import '../../providers/prayer_providers.dart';
import '../../providers/text_scaling_provider.dart';
import '../../widgets/time_of_day_prayer_card.dart';
import '../settings/settings_screen.dart';
import '../categories/categories_screen.dart';
import '../search/search_screen.dart';
import '../prayer/prayer_detail_screen.dart';
import '../prayer/prayer_list_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentDay = ref.watch(currentLiturgicalDayProvider);
    final currentColor = ref.watch(currentLiturgicalColorProvider);
    final colorIntensity = ref.watch(colorIntensityProvider);
    final textScaling = ref.watch(textScaleProvider);
    
    // Parse liturgical color and convert to Flutter color
    final liturgicalColor = currentColor != null 
        ? LiturgicalColor.fromString(currentColor)
        : null;
    final themeColor = liturgicalColor?.toFlutterColor(colorIntensity);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Prayer Companion',
          style: textScaling.scaledTitleLarge(context),
        ),
        backgroundColor: themeColor?.withValues(alpha: 0.1),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false, // Let AppBar handle top
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Liturgical Day Card
            if (currentDay != null) ...[
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: themeColor != null ? Border.all(
                      color: themeColor.withValues(alpha: 0.3),
                      width: 2,
                    ) : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (themeColor != null) ...[
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: themeColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Text(
                                'Today\'s Liturgical Season',
                                style: textScaling.scaledTitleMedium(context).copyWith(
                                  color: themeColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentDay.season,
                          style: textScaling.scaledHeadlineSmall(context).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (currentDay.celebration.name.isNotEmpty && 
                            currentDay.celebration.name != currentDay.season) ...[
                          const SizedBox(height: 4),
                          Text(
                            currentDay.celebration.name,
                            style: textScaling.scaledBodyLarge(context),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // Quick Actions
            Text(
              'Quick Actions',
              style: textScaling.scaledHeadlineSmall(context).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              // Make cards taller when text is larger to prevent overflow
              childAspectRatio: textScaling.scaleFactor > 1.2 ? 0.85 : 1.0,
              children: [
                _buildPrayerOfTheDayCard(context, ref, themeColor),
                TimeOfDayPrayerCard(themeColor: themeColor),
                _buildActionCard(
                  context,
                  icon: Icons.favorite,
                  title: 'Favorites',
                  subtitle: 'Your saved prayers',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const PrayerListScreen(
                          title: 'Favorite Prayers',
                          showFavorites: true,
                        ),
                      ),
                    );
                  },
                ),
                _buildActionCard(
                  context,
                  icon: Icons.category,
                  title: 'Browse Categories',
                  subtitle: 'Explore prayer types',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const CategoriesScreen(),
                      ),
                    );
                  },
                ),
                _buildActionCard(
                  context,
                  icon: Icons.search,
                  title: 'Search Prayers',
                  subtitle: 'Find specific prayers',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SearchScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerOfTheDayCard(BuildContext context, WidgetRef ref, Color? themeColor) {
    final prayerOfTheDayAsync = ref.watch(prayerOfTheDayProvider);
    final prayerContext = ref.watch(prayerOfTheDayContextProvider);
    final textScaling = ref.watch(textScaleProvider);

    return prayerOfTheDayAsync.when(
      data: (prayer) {
        if (prayer == null) {
          return _buildActionCard(
            context,
            icon: Icons.auto_awesome,
            title: 'Prayer of the Day',
            subtitle: 'No prayer available today',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No prayer of the day available')),
              );
            },
          );
        }

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PrayerDetailScreen(prayerId: prayer.id),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: themeColor != null ? Border.all(
                  color: themeColor.withValues(alpha: 0.3),
                  width: 2,
                ) : null,
              ),
              child: Padding(
                padding: EdgeInsets.all(textScaling.scaleFactor > 1.2 ? 12 : 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: textScaling.scaleFactor > 1.2 ? 16 : 20,
                          color: themeColor ?? Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Prayer of the Day',
                            style: textScaling.scaledTitleSmall(context).copyWith(
                              color: themeColor?.withValues(alpha: 0.8) ?? 
                                     Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: textScaling.scaleFactor > 1.2 ? 8 : 12),
                    Flexible(
                      child: Text(
                        prayer.title,
                        style: textScaling.scaledTitleMedium(context).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: textScaling.scaleFactor > 1.2 ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: textScaling.scaleFactor > 1.2 ? 4 : 8),
                    Flexible(
                      child: Text(
                        prayer.description,
                        style: textScaling.scaledBodySmall(context).copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (prayerContext['reason']?.isNotEmpty == true && textScaling.scaleFactor <= 1.2) ...[
                      SizedBox(height: textScaling.scaleFactor > 1.2 ? 4 : 8),
                      Flexible(
                        child: Text(
                          prayerContext['reason']!,
                          style: textScaling.scaledLabelSmall(context).copyWith(
                            color: themeColor?.withValues(alpha: 0.7) ?? 
                                   Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => _buildActionCard(
        context,
        icon: Icons.auto_awesome,
        title: 'Prayer of the Day',
        subtitle: 'Loading...',
        onTap: () {},
      ),
      error: (error, stack) => _buildActionCard(
        context,
        icon: Icons.auto_awesome,
        title: 'Prayer of the Day',
        subtitle: 'Error loading prayer',
        onTap: () {
          ref.invalidate(prayerOfTheDayProvider);
        },
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    // Get text scaling from context
    // Note: We can't use ref.watch here since this is a method not a widget build
    // The scaling will be applied when the parent rebuilds
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Consumer(
          builder: (context, ref, child) {
            final textScaling = ref.watch(textScaleProvider);
            return Padding(
              padding: EdgeInsets.all(textScaling.scaleFactor > 1.2 ? 12 : 16), // Less padding for larger text
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Icon(
                      icon,
                      size: textScaling.scaleFactor > 1.2 ? 24 : 32, // Smaller icon for larger text
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: textScaling.scaleFactor > 1.2 ? 8 : 12), // Less spacing for larger text
                  Flexible(
                    flex: 2,
                    child: Text(
                      title,
                      style: textScaling.scaledTitleMedium(context).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (textScaling.scaleFactor <= 1.2) ...[
                    const SizedBox(height: 4),
                    Flexible(
                      child: Text(
                        subtitle,
                        style: textScaling.scaledBodySmall(context).copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}