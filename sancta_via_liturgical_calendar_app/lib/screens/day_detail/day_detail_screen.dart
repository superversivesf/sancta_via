import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';
import '../../providers/calendar_providers.dart' as local_providers;

class DayDetailScreen extends ConsumerWidget {
  final DateTime date;

  const DayDetailScreen({required this.date, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liturgicalDay = ref.watch(
      local_providers.liturgicalDayForDateProvider(date),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('MMMM d, yyyy').format(date)),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false, // Let AppBar handle top
        child: liturgicalDay != null
            ? _buildDayDetail(context, ref, liturgicalDay)
            : _buildNoDataState(context),
      ),
    );
  }

  Widget _buildDayDetail(
    BuildContext context,
    WidgetRef ref,
    LiturgicalDayData liturgicalDay,
  ) {
    final theme = Theme.of(context);
    final colorIntensity = ref.watch(colorIntensityProvider);
    final liturgicalColor = liturgicalDay.celebration.color.toLiturgicalColor(
      colorIntensity,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main liturgical information card
          Card(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: liturgicalColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: liturgicalColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date header with liturgical color
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: liturgicalColor,
                        radius: 12,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          DateFormat('EEEE, MMMM d, yyyy').format(date),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Season
                  _buildInfoRow(
                    context,
                    'Liturgical Season',
                    liturgicalDay.season,
                    Icons.calendar_today,
                  ),

                  // Celebration
                  if (liturgicalDay.celebration.name.isNotEmpty)
                    _buildInfoRow(
                      context,
                      'Celebration',
                      liturgicalDay.celebration.name,
                      _getCelebrationIcon(liturgicalDay),
                    ),

                  // Rank
                  if (liturgicalDay.celebration.rank != 'WEEKDAY')
                    _buildInfoRow(
                      context,
                      'Rank',
                      _formatRank(liturgicalDay.celebration.rank),
                      Icons.military_tech,
                    ),

                  // Liturgical Color
                  _buildInfoRow(
                    context,
                    'Liturgical Color',
                    _formatColor(liturgicalDay.celebration.color),
                    Icons.palette,
                    colorIndicator: liturgicalColor,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Liturgical Year Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Liturgical Year Information',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildInfoRow(
                    context,
                    'Liturgical Year',
                    liturgicalDay.liturgicalYear.cycle.value,
                    Icons.refresh,
                  ),

                  _buildInfoRow(
                    context,
                    'Psalter Week',
                    liturgicalDay.psalterWeek.value.toString(),
                    Icons.book,
                  ),
                ],
              ),
            ),
          ),

          // Prioritized celebration indicator
          if (liturgicalDay.celebration.prioritized) ...[
            const SizedBox(height: 20),
            Card(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber[700], size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This is a prioritized celebration in the liturgical calendar',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? colorIndicator,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (colorIndicator != null) ...[
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: colorIndicator,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.outline,
                            width: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        value,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month, size: 64),
          SizedBox(height: 16),
          Text('No liturgical data available for this date'),
        ],
      ),
    );
  }

  IconData _getCelebrationIcon(LiturgicalDayData liturgicalDay) {
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
            : Icons.event;
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

  String _formatColor(String color) {
    switch (color.toUpperCase()) {
      case 'GREEN':
        return 'Green';
      case 'PURPLE':
        return 'Purple';
      case 'ROSE':
        return 'Rose';
      case 'WHITE':
        return 'White';
      case 'RED':
        return 'Red';
      case 'GOLD':
        return 'Gold';
      default:
        return color;
    }
  }
}
