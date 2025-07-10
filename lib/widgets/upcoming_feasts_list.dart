import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';

class UpcomingFeastsList extends ConsumerWidget {
  final List<LiturgicalDayData> feasts;

  const UpcomingFeastsList({
    required this.feasts,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorIntensity = ref.watch(colorIntensityProvider);
    
    if (feasts.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16), // Normal padding now that we have space
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Upcoming Feasts & Celebrations',
            style: theme.textTheme.titleMedium?.copyWith( // Back to larger title
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          // Use SingleChildScrollView with Row for proper intrinsic height support
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: feasts.map((feast) => _buildFeastCard(context, feast, colorIntensity)).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeastCard(BuildContext context, LiturgicalDayData feast, ColorIntensity colorIntensity) {
    final theme = Theme.of(context);
    final feastColor = feast.celebration.color.toLiturgicalColor(colorIntensity);
    final feastDate = DateTime.parse(feast.date);
    
    return Container(
      width: 160, // Keep consistent width
      // Remove fixed height - let it size based on content
      constraints: const BoxConstraints(
        minHeight: 100, // Minimum height for consistency
      ),
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12), // Increased padding for larger text
      decoration: BoxDecoration(
        color: feastColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: feastColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Size to content
        children: [
          // Date and rank indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  DateFormat('MMM d').format(feastDate),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: feastColor,
                  ),
                ),
              ),
              if (feast.celebration.prioritized || feast.celebration.rank == 'SOLEMNITY')
                Icon(
                  Icons.star,
                  size: 16, // Responsive to text scaling
                  color: feastColor,
                ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Celebration name - flexible sizing
          Text(
            feast.celebration.name.isEmpty 
                ? feast.season 
                : feast.celebration.name,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: feast.celebration.rank == 'SOLEMNITY' 
                  ? FontWeight.bold 
                  : FontWeight.normal,
              height: 1.3,
            ),
            // Remove maxLines and ellipsis to allow full text display
          ),
          
          // Rank - show for significant celebrations
          if ((feast.celebration.rank == 'SOLEMNITY' || 
               feast.celebration.rank == 'FEAST' ||
               feast.celebration.rank == 'MEMORIAL') && 
              feast.celebration.rank.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _formatRank(feast.celebration.rank),
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
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
      default:
        return rank;
    }
  }
}