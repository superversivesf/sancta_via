import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';

class UpcomingFeastsList extends ConsumerWidget {
  final List<LiturgicalDayData> feasts;

  const UpcomingFeastsList({
    super.key,
    required this.feasts,
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
          const SizedBox(height: 12), // More breathing room
          SizedBox(
            height: 120, // More comfortable height for cards
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: feasts.length,
              itemBuilder: (context, index) {
                final feast = feasts[index];
                return _buildFeastCard(context, feast, colorIntensity);
              },
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
      width: 160, // Back to comfortable width
      height: 120, // Match the ListView height
      margin: const EdgeInsets.only(right: 12), // Normal margin
      padding: const EdgeInsets.all(8), // More comfortable padding
      decoration: BoxDecoration(
        color: feastColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8), // Smaller radius
        border: Border.all(
          color: feastColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date and rank indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMM d').format(feastDate),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: feastColor,
                  fontSize: 11, // Slightly larger
                ),
              ),
              if (feast.celebration.prioritized || feast.celebration.rank == 'SOLEMNITY')
                Icon(
                  Icons.star,
                  size: 14, // Slightly larger
                  color: feastColor,
                ),
            ],
          ),
          const SizedBox(height: 6), // More spacing
          
          // Celebration name - take up remaining space
          Expanded(
            child: Text(
              feast.celebration.name.isEmpty 
                  ? feast.season 
                  : feast.celebration.name,
              style: theme.textTheme.bodyMedium?.copyWith( // Back to bodyMedium
                fontWeight: feast.celebration.rank == 'SOLEMNITY' 
                    ? FontWeight.bold 
                    : FontWeight.normal,
                fontSize: 12,
                height: 1.3, // Better line height
              ),
              maxLines: 3, // Good balance
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Rank - show for more celebrations now that we have space
          if ((feast.celebration.rank == 'SOLEMNITY' || 
               feast.celebration.rank == 'FEAST' ||
               feast.celebration.rank == 'MEMORIAL') && 
              feast.celebration.rank.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              _formatRank(feast.celebration.rank),
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10, // Slightly larger
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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