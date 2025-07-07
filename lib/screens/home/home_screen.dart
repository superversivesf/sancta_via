import 'package:flutter/material.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import '../../providers/text_scaling_provider.dart';
import '../settings/settings_screen.dart';
import '../bible_lookup/bible_lookup_screen.dart';
import '../reading_plan/reading_plan_screen.dart';
import '../bible_search/bible_search_screen.dart';
import '../continue_reading/continue_reading_screen.dart';

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
          'Bible Reading App',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Liturgical Day Card (keep this - it's beautiful!)
            if (currentDay != null) ...[
              Card(
                margin: const EdgeInsets.only(bottom: 24),
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

            // Welcome Header
            Text(
              'Choose your Bible reading experience',
              style: textScaling.scaledHeadlineSmall(context).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Navigation Options
            _buildNavigationGrid(context, ref, themeColor),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationGrid(BuildContext context, WidgetRef ref, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Column(
      children: [
        // Row 1: Bible Lookup & Reading Plans
        Row(
          children: [
            Expanded(
              child: _buildNavigationCard(
                context: context,
                textScaling: textScaling,
                themeColor: themeColor,
                title: 'Bible Lookup',
                subtitle: 'Read any chapter',
                icon: Icons.menu_book,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BibleLookupScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildNavigationCard(
                context: context,
                textScaling: textScaling,
                themeColor: themeColor,
                title: 'Reading Plans',
                subtitle: 'Structured reading',
                icon: Icons.calendar_today,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReadingPlanScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Row 2: Continue Reading & Bible Search
        Row(
          children: [
            Expanded(
              child: _buildNavigationCard(
                context: context,
                textScaling: textScaling,
                themeColor: themeColor,
                title: 'Continue Reading',
                subtitle: 'Pick up where you left off',
                icon: Icons.play_circle_filled,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ContinueReadingScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildNavigationCard(
                context: context,
                textScaling: textScaling,
                themeColor: themeColor,
                title: 'Search Bible',
                subtitle: 'Find verses & topics',
                icon: Icons.search,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BibleSearchScreen()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavigationCard({
    required BuildContext context,
    required TextScaling textScaling,
    required Color? themeColor,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 140, // Increased height to prevent overflow
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: themeColor != null ? Border.all(
              color: themeColor.withValues(alpha: 0.3),
              width: 2,
            ) : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12), // Reduced padding slightly
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // Added to prevent overflow
              children: [
                Icon(
                  icon,
                  size: textScaling.scaleFactor * 28, // Slightly smaller icon
                  color: themeColor ?? Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8), // Reduced spacing
                Flexible( // Made text flexible
                  child: Text(
                    title,
                    style: textScaling.scaledTitleSmall(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: themeColor?.withValues(alpha: 0.8) ?? 
                             Theme.of(context).colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Flexible( // Made subtitle flexible
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
            ),
          ),
        ),
      ),
    );
  }
}
