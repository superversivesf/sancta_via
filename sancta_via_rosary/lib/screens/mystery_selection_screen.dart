import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';

import '../models/models.dart';

/// Provider for the currently selected mystery set
final selectedMysterySetProvider = StateProvider<MysterySet>((ref) {
  // Default to today's recommendation
  return MysterySet.forToday();
});

/// Mystery selection screen with liturgical calendar integration
///
/// Displays all 4 mystery sets with recommendations based on the current day.
/// - Monday, Saturday: Joyful Mysteries
/// - Tuesday, Friday: Sorrowful Mysteries
/// - Wednesday, Sunday: Glorious Mysteries
/// - Thursday: Luminous Mysteries
///
/// Users can override the recommendation by selecting any set manually.
class MysterySelectionScreen extends ConsumerStatefulWidget {
  /// Creates a mystery selection screen
  const MysterySelectionScreen({super.key});

  @override
  ConsumerState<MysterySelectionScreen> createState() =>
      _MysterySelectionScreenState();
}

class _MysterySelectionScreenState
    extends ConsumerState<MysterySelectionScreen> {
  @override
  Widget build(BuildContext context) {
    final liturgicalColor = ref.watch(liturgicalColorProvider);
    final liturgicalDay = ref.watch(currentLiturgicalDayProvider);
    final selectedSet = ref.watch(selectedMysterySetProvider);
    final recommendedSet = MysterySet.forToday();
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Mysteries'),
        centerTitle: true,
        backgroundColor: liturgicalColor,
        foregroundColor: _getContrastingColor(liturgicalColor),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header with today's liturgical info
            SliverToBoxAdapter(
              child: _buildHeader(
                context,
                liturgicalDay,
                today,
                recommendedSet,
              ),
            ),

            // Mystery set cards
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Joyful Mysteries Card
                  _MysterySetCard(
                    set: MysterySet.joyful,
                    isSelected: selectedSet == MysterySet.joyful,
                    isRecommended: recommendedSet == MysterySet.joyful,
                    onTap: () => _selectMysterySet(MysterySet.joyful),
                  ),
                  const SizedBox(height: 16),

                  // Sorrowful Mysteries Card
                  _MysterySetCard(
                    set: MysterySet.sorrowful,
                    isSelected: selectedSet == MysterySet.sorrowful,
                    isRecommended: recommendedSet == MysterySet.sorrowful,
                    onTap: () => _selectMysterySet(MysterySet.sorrowful),
                  ),
                  const SizedBox(height: 16),

                  // Glorious Mysteries Card
                  _MysterySetCard(
                    set: MysterySet.glorious,
                    isSelected: selectedSet == MysterySet.glorious,
                    isRecommended: recommendedSet == MysterySet.glorious,
                    onTap: () => _selectMysterySet(MysterySet.glorious),
                  ),
                  const SizedBox(height: 16),

                  // Luminous Mysteries Card
                  _MysterySetCard(
                    set: MysterySet.luminous,
                    isSelected: selectedSet == MysterySet.luminous,
                    isRecommended: recommendedSet == MysterySet.luminous,
                    onTap: () => _selectMysterySet(MysterySet.luminous),
                  ),
                  const SizedBox(height: 32),
                ]),
              ),
            ),

            // Start Rosary Button
            SliverFillRemaining(
              hasScrollBody: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => _startRosary(selectedSet),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: liturgicalColor,
                        foregroundColor: _getContrastingColor(liturgicalColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.play_arrow, size: 28),
                      label: Text(
                        'Start Rosary',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: _getContrastingColor(liturgicalColor),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    LiturgicalDayData? liturgicalDay,
    DateTime today,
    MysterySet recommendedSet,
  ) {
    final theme = Theme.of(context);
    final dayName = _getDayName(today.weekday);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            Theme.of(context).colorScheme.surface,
          ],
        ),
      ),
      child: Column(
        children: [
          // Liturgical info if available
          if (liturgicalDay != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getLiturgicalIcon(liturgicalDay.season),
                    size: 18,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${liturgicalDay.season} • ${liturgicalDay.celebration.name}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Today's recommendation
          Text(
            'Today is $dayName',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Recommended: ${recommendedSet.displayName}',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select any set to begin your prayer',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  void _selectMysterySet(MysterySet set) {
    setState(() {
      ref.read(selectedMysterySetProvider.notifier).state = set;
    });
  }

  void _startRosary(MysterySet selectedSet) {
    // Navigate to the rosary prayer screen with the selected set
    context.push('/rosary/${selectedSet.name}');
  }

  String _getDayName(int weekday) {
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }

  Color _getContrastingColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  IconData _getLiturgicalIcon(String? season) {
    switch (season?.toLowerCase()) {
      case 'advent':
        return Icons.auto_awesome;
      case 'christmas':
      case 'christmastide':
        return Icons.celebration;
      case 'lent':
        return Icons.self_improvement;
      case 'easter':
      case 'eastertide':
        return Icons.wb_sunny;
      case 'ordinary time':
      case 'early ordinary time':
        return Icons.calendar_today;
      default:
        return Icons.church;
    }
  }
}

/// Card widget for displaying a mystery set
class _MysterySetCard extends ConsumerWidget {
  /// The mystery set to display
  final MysterySet set;

  /// Whether this set is currently selected
  final bool isSelected;

  /// Whether this set is recommended for today
  final bool isRecommended;

  /// Callback when the card is tapped
  final VoidCallback onTap;

  /// Creates a mystery set card
  const _MysterySetCard({
    required this.set,
    required this.isSelected,
    required this.isRecommended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final setColor = _getSetColor(set);
    final setIcon = _getSetIcon(set);
    final mysteries = _getMysteryNames(set);

    return Card(
      elevation: isSelected ? 6 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? setColor : Colors.transparent,
          width: isSelected ? 3 : 0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                setColor.withValues(alpha: 0.15),
                theme.colorScheme.surface,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon and title
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: setColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: setColor.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(setIcon, size: 32, color: setColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            set.displayName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getSetDescription(set),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: setColor, size: 28),
                  ],
                ),

                // Recommended badge
                if (isRecommended) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: setColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: setColor.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 16, color: setColor),
                        const SizedBox(width: 6),
                        Text(
                          'Recommended for today',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: setColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Mystery list
                ...mysteries.asMap().entries.map((entry) {
                  final index = entry.key;
                  final mystery = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: setColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: setColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            mystery,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getSetColor(MysterySet set) {
    switch (set) {
      case MysterySet.joyful:
        return const Color(0xFF4CAF50); // Green
      case MysterySet.sorrowful:
        return const Color(0xFF9C27B0); // Purple
      case MysterySet.glorious:
        return const Color(0xFFFFB300); // Gold
      case MysterySet.luminous:
        return const Color(0xFF2196F3); // Blue
    }
  }

  IconData _getSetIcon(MysterySet set) {
    switch (set) {
      case MysterySet.joyful:
        return Icons.emoji_emotions;
      case MysterySet.sorrowful:
        return Icons.favorite;
      case MysterySet.glorious:
        return Icons.wb_sunny;
      case MysterySet.luminous:
        return Icons.lightbulb;
    }
  }

  String _getSetDescription(MysterySet set) {
    switch (set) {
      case MysterySet.joyful:
        return 'Meditations on the early life of Christ';
      case MysterySet.sorrowful:
        return 'Meditations on Christ\'s Passion and suffering';
      case MysterySet.glorious:
        return 'Meditations on the Risen and Glorified Christ';
      case MysterySet.luminous:
        return 'Meditations on Christ\'s public ministry';
    }
  }

  List<String> _getMysteryNames(MysterySet set) {
    switch (set) {
      case MysterySet.joyful:
        return [
          'The Annunciation',
          'The Visitation',
          'The Nativity',
          'The Presentation',
          'The Finding in the Temple',
        ];
      case MysterySet.sorrowful:
        return [
          'The Agony in the Garden',
          'The Scourging at the Pillar',
          'The Crowning with Thorns',
          'The Carrying of the Cross',
          'The Crucifixion',
        ];
      case MysterySet.glorious:
        return [
          'The Resurrection',
          'The Ascension',
          'The Descent of the Holy Spirit',
          'The Assumption',
          'The Coronation',
        ];
      case MysterySet.luminous:
        return [
          'The Baptism in the Jordan',
          'The Wedding at Cana',
          'The Proclamation of the Kingdom',
          'The Transfiguration',
          'The Institution of the Eucharist',
        ];
    }
  }
}
