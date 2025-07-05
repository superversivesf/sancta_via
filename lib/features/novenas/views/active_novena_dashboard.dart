import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/novena.dart';
import '../providers/novena_providers.dart';
import '../providers/novena_notification_provider.dart';
import '../../../config/route_names.dart';
import '../providers/novena_state_provider.dart';
import '../../../utils/logger.dart';

class ActiveNovenaDashboard extends ConsumerWidget {
  const ActiveNovenaDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeNovena = ref.watch(novenaStateProvider);
    final notificationsReady = ref.watch(notificationsReadyProvider);
    
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
        title: const Text('Your Novena'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            context.goNamed(RouteNames.home);
          },
          tooltip: 'Back to Home',
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'cancel') {
                _showCancelDialog(context, ref);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'cancel',
                child: Row(
                  children: [
                    Icon(Icons.cancel_outlined),
                    SizedBox(width: 8),
                    Text('Cancel Novena'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: novenaAsync.when(
        data: (novena) {
          if (novena == null) {
            return const Center(child: Text('Novena not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section
                _buildHeaderSection(context, activeNovena, novena),
                const SizedBox(height: 24),

                // Today's prayer section
                _buildTodaySection(context, ref, activeNovena),
                const SizedBox(height: 24),

                // Progress overview
                _buildProgressSection(context, activeNovena),
                const SizedBox(height: 24),

                // Notification status
                _buildNotificationSection(context, activeNovena, notificationsReady),
                const SizedBox(height: 24),

                // Days grid
                _buildDaysGrid(context, activeNovena),
              ],
            ),
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

  Widget _buildHeaderSection(BuildContext context, ActiveNovena activeNovena, Novena novena) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            novena.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            novena.saint,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Day ${activeNovena.spiritualDay} of 9',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: activeNovena.progressPercentage,
            backgroundColor: Theme.of(context).colorScheme.outline.withAlpha(77),
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(activeNovena.progressPercentage * 100).round()}% Complete',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySection(BuildContext context, WidgetRef ref, ActiveNovena activeNovena) {
    final spiritualDay = activeNovena.spiritualDay;
    final isTodayComplete = activeNovena.isTodayComplete;
    final nextIncompleteDay = activeNovena.nextIncompleteDay;
    
    // If all accessible days are complete, show encouraging message
    final allAccessibleComplete = nextIncompleteDay == spiritualDay && isTodayComplete;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isTodayComplete 
            ? Theme.of(context).colorScheme.tertiaryContainer
            : Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isTodayComplete ? Icons.check_circle : Icons.schedule,
                color: isTodayComplete 
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Today\'s Prayer',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isTodayComplete 
                ? allAccessibleComplete
                    ? 'You\'ve completed Day $spiritualDay! You\'re up to date with your novena.'
                    : 'You\'ve completed Day $spiritualDay! You can catch up on previous days if needed.'
                : 'Day $spiritualDay prayer is ready for you.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: spiritualDay <= 9 ? () {
                AppLogger.debug('Navigating to daily prayer for day $nextIncompleteDay', 'NOVENA_UI');
                context.pushNamed(
                  RouteNames.dailyNovena,
                  pathParameters: {'dayNumber': nextIncompleteDay.toString()},
                );
              } : null,
              icon: Icon(isTodayComplete ? Icons.visibility : Icons.play_arrow),
              label: Text(
                isTodayComplete 
                    ? allAccessibleComplete 
                        ? 'Review Today\'s Prayer' 
                        : 'Continue Prayer Journey'
                    : 'Begin Today\'s Prayer'
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(BuildContext context, ActiveNovena activeNovena) {
    final completedCount = activeNovena.accessibleCompletedCount;
    
    // Debug logging to understand the discrepancy
    AppLogger.debug('=== PROGRESS DEBUG ===', 'NOVENA_DEBUG');
    AppLogger.debug('Spiritual Day: ${activeNovena.spiritualDay}', 'NOVENA_DEBUG');
    AppLogger.debug('Completed Days Array: ${activeNovena.completedDays}', 'NOVENA_DEBUG');
    AppLogger.debug('Raw Completed Count: ${activeNovena.completedDays.where((day) => day).length}', 'NOVENA_DEBUG');
    AppLogger.debug('Accessible Completed Count: $completedCount', 'NOVENA_DEBUG');
    AppLogger.debug('Start Date: ${activeNovena.startDate}', 'NOVENA_DEBUG');
    AppLogger.debug('Current Date: ${DateTime.now()}', 'NOVENA_DEBUG');
    AppLogger.debug('==================', 'NOVENA_DEBUG');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress Overview',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context,
                'Completed',
                completedCount.toString(),
                Icons.check_circle,
                Theme.of(context).colorScheme.tertiary,
              ),
              _buildStatItem(
                context,
                'Remaining',
                (9 - completedCount).toString(),
                Icons.schedule,
                Theme.of(context).colorScheme.primary,
              ),
              _buildStatItem(
                context,
                'Current Day',
                activeNovena.spiritualDay.toString(),
                Icons.today,
                Theme.of(context).colorScheme.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildDaysGrid(BuildContext context, ActiveNovena activeNovena) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nine Days of Prayer',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: 9,
          itemBuilder: (context, index) {
            final dayNumber = index + 1;
            final isCompleted = activeNovena.isDayComplete(dayNumber);
            final isAccessible = activeNovena.canAccessDay(dayNumber);
            
            final isToday = dayNumber == activeNovena.spiritualDay && !activeNovena.isTodayComplete;

            return InkWell(
              onTap: isAccessible ? () {
                AppLogger.debug('Grid navigation to day $dayNumber', 'NOVENA_UI');
                context.pushNamed(
                  RouteNames.dailyNovena,
                  pathParameters: {'dayNumber': dayNumber.toString()},
                );
              } : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Theme.of(context).colorScheme.tertiaryContainer
                      : isToday
                          ? Theme.of(context).colorScheme.primaryContainer
                          : isAccessible
                              ? Theme.of(context).colorScheme.surfaceContainerHighest
                              : Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128),
                  borderRadius: BorderRadius.circular(12),
                  border: isToday
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isCompleted 
                          ? Icons.check_circle
                          : isToday
                              ? Icons.play_circle_filled
                              : isAccessible
                                  ? Icons.circle_outlined
                                  : Icons.lock_outline,
                      color: isCompleted
                          ? Theme.of(context).colorScheme.tertiary
                          : isToday
                              ? Theme.of(context).colorScheme.primary
                              : isAccessible
                                  ? Theme.of(context).colorScheme.outline
                                  : Theme.of(context).colorScheme.outline.withAlpha(128),
                      size: 28,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Day $dayNumber',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: isToday ? FontWeight.bold : null,
                        color: isAccessible
                            ? null
                            : Theme.of(context).colorScheme.outline.withAlpha(128),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Novena'),
          content: const Text(
            'Are you sure you want to cancel your current novena? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Keep Novena'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await ref.read(novenaStateProvider.notifier).clearActiveNovena();
                if (context.mounted) {
                  context.goNamed(RouteNames.novenas);
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Cancel Novena'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNotificationSection(BuildContext context, ActiveNovena activeNovena, bool notificationsReady) {
    final nextReminderTime = _getNextReminderTime(activeNovena);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: notificationsReady 
            ? Theme.of(context).colorScheme.primaryContainer.withAlpha(128)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(51),
        ),
      ),
      child: Row(
        children: [
          Icon(
            notificationsReady ? Icons.schedule : Icons.notifications_off_outlined,
            color: notificationsReady 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notificationsReady ? 'Daily Reminders Active' : 'Notifications Off',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (notificationsReady && nextReminderTime != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Next reminder: ${_formatTime(activeNovena.reminderTime)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
                    ),
                  ),
                ] else if (!notificationsReady) ...[
                  const SizedBox(height: 2),
                  Text(
                    'You can still track your progress manually',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _getNextReminderTime(ActiveNovena activeNovena) {
    final now = DateTime.now();
    final spiritualDay = activeNovena.spiritualDay;
    
    if (spiritualDay > 9) return null; // Novena complete
    
    // Calculate next reminder time
    final today = DateTime.now();
    final todayReminder = DateTime(
      today.year,
      today.month, 
      today.day,
      activeNovena.reminderTime.hour,
      activeNovena.reminderTime.minute,
    );
    
    if (todayReminder.isAfter(now)) {
      return todayReminder; // Today's reminder hasn't happened yet
    } else {
      // Tomorrow's reminder
      final tomorrow = today.add(const Duration(days: 1));
      return DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        activeNovena.reminderTime.hour,
        activeNovena.reminderTime.minute,
      );
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour == 0 ? 12 : time.hour > 12 ? time.hour - 12 : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

}
