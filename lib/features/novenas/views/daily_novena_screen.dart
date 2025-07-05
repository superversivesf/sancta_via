import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/novena_providers.dart';
import '../../../config/route_names.dart';
import '../providers/novena_state_provider.dart';
import '../../../utils/logger.dart';

class DailyNovenaScreen extends ConsumerWidget {
  final int dayNumber;

  const DailyNovenaScreen({
    super.key,
    required this.dayNumber,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeNovena = ref.watch(novenaStateProvider);
    
    if (activeNovena == null) {
      // No active novena, redirect to list
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.goNamed(RouteNames.novenas);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final novenaAsync = ref.watch(novenaByIdProvider(activeNovena.novenaId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Day $dayNumber'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            context.goNamed(RouteNames.activeNovena);
          },
          tooltip: 'Back to Dashboard',
        ),
      ),
      body: novenaAsync.when(
        data: (novena) {
          if (novena == null) {
            return const Center(child: Text('Novena not found'));
          }

          final day = novena.days.firstWhere(
            (d) => d.day == dayNumber,
            orElse: () => throw StateError('Day $dayNumber not found'),
          );

          final isDayComplete = activeNovena.isDayComplete(dayNumber);
          final isAccessible = activeNovena.canAccessDay(dayNumber);
          final isCurrentSpiritualDay = dayNumber == activeNovena.spiritualDay;
          
          // Button is enabled if the day is accessible and not complete
          final buttonEnabled = isAccessible && !isDayComplete;

          return Column(
            children: [
              // Header section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDayComplete 
                      ? Theme.of(context).colorScheme.tertiaryContainer
                      : Theme.of(context).colorScheme.primaryContainer,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isDayComplete ? Icons.check_circle : Icons.auto_awesome,
                          color: isDayComplete 
                              ? Theme.of(context).colorScheme.tertiary
                              : Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Day $dayNumber of 9',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isDayComplete) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• Complete',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.tertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      day.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Prayer content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Opening prayer
                      _buildPrayerSection(
                        context,
                        'Opening Prayer',
                        day.openingPrayer,
                        Icons.start,
                      ),

                      // Scripture (if available)
                      if (day.scripture != null)
                        _buildPrayerSection(
                          context,
                          'Scripture',
                          day.scripture!,
                          Icons.menu_book,
                        ),

                      // Reflection
                      _buildPrayerSection(
                        context,
                        'Reflection',
                        day.reflection,
                        Icons.lightbulb_outline,
                      ),

                      // Daily prayer
                      _buildPrayerSection(
                        context,
                        'Daily Prayer',
                        day.dailyPrayer,
                        Icons.favorite,
                      ),

                      // Intention prayer
                      _buildPrayerSection(
                        context,
                        'Intention Prayer',
                        day.intentionPrayer,
                        Icons.volunteer_activism,
                      ),

                      // Personal intention (if set)
                      if (activeNovena.personalIntention != null)
                        _buildPrayerSection(
                          context,
                          'Your Personal Intention',
                          activeNovena.personalIntention!,
                          Icons.person,
                        ),

                      // Closing prayer
                      _buildPrayerSection(
                        context,
                        'Closing Prayer',
                        day.closingPrayer,
                        Icons.close,
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // Bottom completion button only
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: buttonEnabled ? () {
                      _markAsComplete(context, ref);
                    } : null,
                    icon: Icon(
                      isDayComplete 
                          ? Icons.check_circle 
                          : Icons.check_circle_outline,
                      size: 20,
                    ),
                    label: Text(_getButtonText(buttonEnabled, isDayComplete, isAccessible, isCurrentSpiritualDay, activeNovena.spiritualDay)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDayComplete 
                          ? Theme.of(context).colorScheme.tertiaryContainer
                          : null,
                      foregroundColor: isDayComplete
                          ? Theme.of(context).colorScheme.onTertiaryContainer
                          : null,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Error loading novena: $error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerSection(
    BuildContext context,
    String title,
    String content,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getButtonText(bool buttonEnabled, bool isDayComplete, bool isAccessible, bool isCurrentSpiritualDay, int spiritualDay) {
    if (isDayComplete) {
      return 'Complete';
    }
    
    if (buttonEnabled) {
      return 'Mark as Complete';
    }
    
    if (!isAccessible) {
      return 'Available on Day $spiritualDay';
    }
    
    return 'Already Complete';
  }

  Future<void> _markAsComplete(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(novenaStateProvider.notifier).markTodayComplete();
      
      if (context.mounted) {
        // Show brief success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Day completed! 🙏 Well done.'),
            duration: Duration(seconds: 1),
          ),
        );
        
        // Navigate back to dashboard after brief delay
        await Future.delayed(const Duration(milliseconds: 800));
        if (context.mounted) {
          context.goNamed(RouteNames.activeNovena);
        }
      }
    } catch (e) {
      AppLogger.error('Failed to mark day as complete', e, null, 'NOVENA_UI');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark as complete: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

}
