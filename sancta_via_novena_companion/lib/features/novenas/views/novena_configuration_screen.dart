import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/novena.dart';
import '../providers/novena_providers.dart';
import '../providers/novena_notification_provider.dart';
import '../../../config/route_names.dart';
import '../providers/novena_state_provider.dart';

class NovenaConfigurationScreen extends ConsumerStatefulWidget {
  final String novenaId;

  const NovenaConfigurationScreen({required this.novenaId, super.key});

  @override
  ConsumerState<NovenaConfigurationScreen> createState() =>
      _NovenaConfigurationScreenState();
}

class _NovenaConfigurationScreenState
    extends ConsumerState<NovenaConfigurationScreen> {
  DateTime _startDate = DateTime.now();
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  ReminderInterval _reminderFrequency = ReminderInterval.threeHours;
  final TextEditingController _intentionController = TextEditingController();
  bool _isStarting = false;

  @override
  void dispose() {
    _intentionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final novenaAsync = ref.watch(novenaByIdProvider(widget.novenaId));
    final notificationsReady = ref.watch(notificationsReadyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configure Novena')),
      body: novenaAsync.when(
        data: (novena) {
          if (novena == null) {
            return const Center(child: Text('Novena not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Configure Your Novena',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  novena.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Start date section
                _buildSection(
                  context,
                  title: 'Start Date',
                  icon: Icons.calendar_today,
                  child: InkWell(
                    onTap: _selectStartDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _formatDate(_startDate),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_drop_down,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Reminder time section
                _buildSection(
                  context,
                  title: 'Daily Reminder Time',
                  icon: Icons.access_time,
                  child: InkWell(
                    onTap: _selectReminderTime,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _formatTime(_reminderTime),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_drop_down,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Reminder frequency section
                _buildSection(
                  context,
                  title: 'Reminder Frequency',
                  icon: Icons.notifications,
                  subtitle:
                      'How often to remind you if you haven\'t prayed yet',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ReminderInterval.values.map((interval) {
                      final isSelected = _reminderFrequency == interval;
                      return FilterChip(
                        label: Text(interval.displayName),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _reminderFrequency = interval;
                            });
                          }
                        },
                        selectedColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        side: BorderSide(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Personal intention section
                _buildSection(
                  context,
                  title: 'Personal Intention (Optional)',
                  icon: Icons.favorite,
                  subtitle:
                      'Share your specific prayer intention for this novena',
                  child: TextField(
                    controller: _intentionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter your personal intention...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

                // Notification status section
                _buildNotificationStatusSection(context, notificationsReady),

                const SizedBox(height: 32),

                // Start button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isStarting ? null : _startNovena,
                    icon: _isStarting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(_isStarting ? 'Starting...' : 'Start Novena'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
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

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) {
      setState(() {
        _startDate = date;
      });
    }
  }

  Future<void> _selectReminderTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (time != null) {
      setState(() {
        _reminderTime = time;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour == 0
        ? 12
        : time.hour > 12
        ? time.hour - 12
        : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _startNovena() async {
    setState(() {
      _isStarting = true;
    });

    try {
      // Normalize start date to 00:00:01 of the selected day
      // This ensures novena days change at midnight, not at the time the user configured
      final normalizedStartDate = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        0, // hour
        0, // minute
        1, // second (1 second past midnight)
      );

      final activeNovena = ActiveNovena(
        novenaId: widget.novenaId,
        startDate: normalizedStartDate,
        reminderTime: _reminderTime,
        reminderFrequency: _reminderFrequency,
        personalIntention: _intentionController.text.trim().isEmpty
            ? null
            : _intentionController.text.trim(),
        completedDays: List.filled(9, false),
      );

      // Get novena for title
      final novena = await ref.read(novenaByIdProvider(widget.novenaId).future);
      final novenaTitle = novena?.title ?? 'Novena';

      await ref
          .read(novenaStateProvider.notifier)
          .startNovena(activeNovena, novenaTitle);

      if (mounted) {
        // Navigate to active novena dashboard
        context.goNamed(RouteNames.activeNovena);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start novena: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      }
    }
  }

  Widget _buildNotificationStatusSection(
    BuildContext context,
    bool notificationsReady,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: notificationsReady
            ? Theme.of(context).colorScheme.tertiaryContainer
            : Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            notificationsReady
                ? Icons.notifications_active
                : Icons.notifications_off,
            color: notificationsReady
                ? Theme.of(context).colorScheme.tertiary
                : Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notificationsReady
                      ? 'Notifications Enabled'
                      : 'Notifications Unavailable',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: notificationsReady
                        ? Theme.of(context).colorScheme.onTertiaryContainer
                        : Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notificationsReady
                      ? 'You\'ll receive daily reminders and follow-ups based on your settings'
                      : 'Notifications aren\'t available, but you can still use the novena',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: notificationsReady
                        ? Theme.of(context).colorScheme.onTertiaryContainer
                        : Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
