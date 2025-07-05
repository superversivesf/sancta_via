import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/prayer_metadata.dart';
import '../providers/prayer_providers.dart';
import '../providers/text_scaling_provider.dart';

class PrayerCard extends ConsumerWidget {
  final PrayerMetadata prayer;
  final VoidCallback onTap;
  final Color? themeColor;

  const PrayerCard({
    super.key,
    required this.prayer,
    required this.onTap,
    this.themeColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(prayerPreferencesProvider);
    final textScaling = ref.watch(textScaleProvider);
    final isFavorite = preferences.favoritePrayerIds.contains(prayer.id);
    final isRecent = preferences.recentPrayerIds.contains(prayer.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: themeColor != null ? Border.all(
              color: themeColor!.withValues(alpha: 0.2),
              width: 1,
            ) : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        prayer.title,
                        style: textScaling.scaledTitleMedium(context).copyWith(
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isRecent) ...[
                          Icon(
                            Icons.history,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (isFavorite) 
                          Icon(
                            Icons.favorite,
                            size: 16,
                            color: themeColor ?? Colors.red,
                          ),
                        if (prayer.isLiturgical)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: themeColor?.withValues(alpha: 0.7) ?? 
                                     Theme.of(context).colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  prayer.description,
                  style: textScaling.scaledBodyMedium(context).copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: textScaling.scaleFactor > 1.2 ? 1 : 2, // Reduce lines for larger text
                  overflow: TextOverflow.ellipsis,
                ),
                
                if (prayer.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: prayer.tags.take(textScaling.scaleFactor > 1.2 ? 2 : 3).map((tag) { // Fewer tags for larger text
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: themeColor?.withValues(alpha: 0.1) ?? 
                                 Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: themeColor != null ? Border.all(
                            color: themeColor!.withValues(alpha: 0.3),
                            width: 0.5,
                          ) : null,
                        ),
                        child: Text(
                          tag,
                          style: textScaling.scaledLabelSmall(context).copyWith(
                            color: themeColor?.withValues(alpha: 0.8) ?? 
                                   Theme.of(context).colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                
                if (prayer.liturgicalSeason != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: themeColor?.withValues(alpha: 0.7) ?? 
                               Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'For ${prayer.liturgicalSeason}',
                        style: textScaling.scaledLabelSmall(context).copyWith(
                          color: themeColor?.withValues(alpha: 0.7) ?? 
                                 Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}