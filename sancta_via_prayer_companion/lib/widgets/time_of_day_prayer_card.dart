import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/prayer.dart';
import '../providers/time_of_day_prayer_providers.dart';
import '../providers/text_scaling_provider.dart';
import '../screens/prayer/prayer_detail_screen.dart';

/// A card widget that displays a prayer appropriate for the current time of day
///
/// This widget matches the style of the Prayer of the Day card and shows:
/// - The current time period label (e.g., "Morning Prayer")
/// - The selected prayer title
/// - A brief description
///
/// Tapping the card navigates to the full prayer view.
class TimeOfDayPrayerCard extends ConsumerWidget {
  const TimeOfDayPrayerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayerAsync = ref.watch(dailyTimeOfDayPrayerProvider);
    final prayerContext = ref.watch(timeOfDayPrayerContextProvider);
    final textScaling = ref.watch(textScaleProvider);

    return prayerAsync.when(
      data: (prayer) {
        if (prayer == null) {
          return _buildEmptyCard(context, ref, prayerContext);
        }
        return _buildPrayerCard(
          context,
          ref,
          prayer,
          prayerContext,
          textScaling,
        );
      },
      loading: () => _buildLoadingCard(context, ref, prayerContext),
      error: (error, stack) => _buildErrorCard(context, ref, prayerContext),
    );
  }

  Widget _buildPrayerCard(
    BuildContext context,
    WidgetRef ref,
    Prayer prayer,
    Map<String, String> prayerContext,
    TextScaling textScaling,
  ) {
    final panelLabel = prayerContext['panelLabel'] ?? 'Prayer';

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
        child: Padding(
          padding: EdgeInsets.all(textScaling.scaleFactor > 1.2 ? 12 : 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Icon(
                  _getIconForTimeOfDay(prayerContext['timeOfDay']),
                  size: textScaling.scaleFactor > 1.2 ? 24 : 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(height: textScaling.scaleFactor > 1.2 ? 8 : 12),
              Flexible(
                flex: 2,
                child: Text(
                  panelLabel,
                  style: textScaling
                      .scaledTitleMedium(context)
                      .copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildEmptyCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, String> prayerContext,
  ) {
    final textScaling = ref.watch(textScaleProvider);
    final panelLabel = prayerContext['panelLabel'] ?? 'Prayer';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('No $panelLabel available')));
        },
        child: Padding(
          padding: EdgeInsets.all(textScaling.scaleFactor > 1.2 ? 12 : 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getIconForTimeOfDay(prayerContext['timeOfDay']),
                size: textScaling.scaleFactor > 1.2 ? 24 : 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(height: textScaling.scaleFactor > 1.2 ? 8 : 12),
              Flexible(
                child: Text(
                  panelLabel,
                  style: textScaling
                      .scaledTitleMedium(context)
                      .copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (textScaling.scaleFactor <= 1.2) ...[
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    'No prayer available',
                    style: textScaling
                        .scaledBodySmall(context)
                        .copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, String> prayerContext,
  ) {
    final textScaling = ref.watch(textScaleProvider);
    final panelLabel = prayerContext['panelLabel'] ?? 'Prayer';

    return Card(
      child: Padding(
        padding: EdgeInsets.all(textScaling.scaleFactor > 1.2 ? 12 : 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getIconForTimeOfDay(prayerContext['timeOfDay']),
              size: textScaling.scaleFactor > 1.2 ? 24 : 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(height: textScaling.scaleFactor > 1.2 ? 8 : 12),
            Flexible(
              child: Text(
                panelLabel,
                style: textScaling
                    .scaledTitleMedium(context)
                    .copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (textScaling.scaleFactor <= 1.2) ...[
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  'Loading...',
                  style: textScaling
                      .scaledBodySmall(context)
                      .copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, String> prayerContext,
  ) {
    final textScaling = ref.watch(textScaleProvider);
    final panelLabel = prayerContext['panelLabel'] ?? 'Prayer';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          ref.invalidate(dailyTimeOfDayPrayerProvider);
        },
        child: Padding(
          padding: EdgeInsets.all(textScaling.scaleFactor > 1.2 ? 12 : 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getIconForTimeOfDay(prayerContext['timeOfDay']),
                size: textScaling.scaleFactor > 1.2 ? 24 : 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(height: textScaling.scaleFactor > 1.2 ? 8 : 12),
              Flexible(
                child: Text(
                  panelLabel,
                  style: textScaling
                      .scaledTitleMedium(context)
                      .copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (textScaling.scaleFactor <= 1.2) ...[
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    'Error loading prayer',
                    style: textScaling
                        .scaledBodySmall(context)
                        .copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Get an appropriate icon for the time of day
  IconData _getIconForTimeOfDay(String? timeOfDay) {
    switch (timeOfDay) {
      case 'morning':
        return Icons.wb_sunny;
      case 'afternoon':
        return Icons.wb_cloudy;
      case 'evening':
        return Icons.wb_twilight;
      case 'night':
        return Icons.nightlight_round;
      default:
        return Icons.schedule;
    }
  }
}
