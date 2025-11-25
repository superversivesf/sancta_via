import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';

class LiturgicalDayCard extends ConsumerWidget {
  final LiturgicalDayData liturgicalDay;
  final DateTime selectedDate;
  final VoidCallback? onTap;

  const LiturgicalDayCard({
    required this.liturgicalDay,
    required this.selectedDate,
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorIntensity = ref.watch(colorIntensityProvider);
    final liturgicalColor = liturgicalDay.celebration.color.toLiturgicalColor(
      colorIntensity,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: liturgicalColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: liturgicalColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date and liturgical color indicator
            Row(
              children: [
                CircleAvatar(backgroundColor: liturgicalColor, radius: 8),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(selectedDate),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isSignificantCelebration())
                  Icon(_getCelebrationIcon(), color: liturgicalColor, size: 20),
              ],
            ),
            const SizedBox(height: 8),

            // Season
            Text(
              liturgicalDay.season,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            // Celebration name if significant
            if (liturgicalDay.celebration.name.isNotEmpty &&
                liturgicalDay.celebration.name != liturgicalDay.season) ...[
              const SizedBox(height: 4),
              Text(
                liturgicalDay.celebration.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  fontWeight: liturgicalDay.celebration.rank == 'SOLEMNITY'
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ],

            // Rank if applicable
            if (liturgicalDay.celebration.rank != 'WEEKDAY' &&
                liturgicalDay.celebration.rank.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _formatRank(liturgicalDay.celebration.rank),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: liturgicalColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            // "View details" indicator if onTap is provided
            if (onTap != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'View details',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isSignificantCelebration() {
    return liturgicalDay.celebration.prioritized ||
        liturgicalDay.celebration.rank == 'SOLEMNITY' ||
        liturgicalDay.celebration.rank == 'FEAST' ||
        liturgicalDay.celebration.rank == 'MEMORIAL';
  }

  IconData _getCelebrationIcon() {
    switch (liturgicalDay.celebration.rank) {
      case 'SOLEMNITY':
        return Icons.star;
      case 'FEAST':
        return Icons.star_half;
      case 'MEMORIAL':
        return Icons.circle;
      case 'OPT_MEMORIAL':
        return Icons.circle_outlined;
      default:
        return liturgicalDay.celebration.prioritized
            ? Icons.star_outline
            : Icons.circle_outlined;
    }
  }

  String _formatRank(String rank) {
    switch (rank.toUpperCase()) {
      case 'SOLEMNITY':
        return 'Solemnity';
      case 'FEAST':
        return 'Feast';
      case 'MEMORIAL':
        return 'Memorial';
      case 'OPT_MEMORIAL':
        return 'Optional Memorial';
      case 'WEEKDAY':
        return 'Weekday';
      default:
        return rank;
    }
  }
}
