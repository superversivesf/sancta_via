import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import '../../providers/text_scaling_provider.dart';
import '../../providers/reading_plan_provider.dart';
import '../../models/reading_plan.dart';

class ReadingPlanScreen extends ConsumerStatefulWidget {
  const ReadingPlanScreen({super.key});

  @override
  ConsumerState<ReadingPlanScreen> createState() => _ReadingPlanScreenState();
}

class _ReadingPlanScreenState extends ConsumerState<ReadingPlanScreen> {
  BookCollection selectedCollection = BookCollection.wholeBible;
  ReadingFrequency selectedFrequency = ReadingFrequency.daily;
  int chaptersPerDay = 1;
  bool remindersEnabled = false;
  TimeOfDay? reminderTime;

  @override
  Widget build(BuildContext context) {
    final currentColor = ref.watch(currentLiturgicalColorProvider);
    final colorIntensity = ref.watch(colorIntensityProvider);
    final textScaling = ref.watch(textScaleProvider);
    final currentPlan = ref.watch(currentReadingPlanProvider);
    
    // Parse liturgical color and convert to Flutter color
    final liturgicalColor = currentColor != null 
        ? LiturgicalColor.fromString(currentColor)
        : null;
    final themeColor = liturgicalColor?.toFlutterColor(colorIntensity);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reading Plans',
          style: textScaling.scaledTitleLarge(context),
        ),
        backgroundColor: themeColor?.withValues(alpha: 0.1),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Create Your Reading Plan',
              style: textScaling.scaledHeadlineSmall(context).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set up a structured approach to reading through the Bible systematically.',
              style: textScaling.scaledBodyLarge(context).copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),

            // Current Plan Status (if exists)
            if (currentPlan != null) ...[
              _buildCurrentPlanCard(context, currentPlan, themeColor),
              const SizedBox(height: 24),
            ],

            // Book Collection Selection
            _buildCollectionCard(context, themeColor),
            const SizedBox(height: 16),

            // Reading Frequency
            _buildFrequencyCard(context, themeColor),
            const SizedBox(height: 16),

            // Chapters per Day
            _buildChaptersCard(context, themeColor),
            const SizedBox(height: 16),

            // Reminders
            _buildRemindersCard(context, themeColor),
            const SizedBox(height: 24),

            // Create Plan Button
            Center(
              child: ElevatedButton.icon(
                onPressed: _createReadingPlan,
                icon: const Icon(Icons.create),
                label: Text(
                  currentPlan != null ? 'Update Plan' : 'Create Plan',
                  style: textScaling.scaledBodyLarge(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor ?? Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPlanCard(BuildContext context, ReadingPlan plan, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: themeColor != null ? Border.all(
            color: themeColor.withValues(alpha: 0.3),
            width: 2,
          ) : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    color: themeColor ?? Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Current Reading Plan',
                    style: textScaling.scaledTitleMedium(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: themeColor?.withValues(alpha: 0.8) ?? 
                             Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      ref.read(readingPlanProvider.notifier).clearPlan();
                    },
                    child: const Text('Clear Plan'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                plan.collection.displayName,
                style: textScaling.scaledBodyLarge(context).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Progress: ${plan.progress.currentBook} ${plan.progress.currentChapter}',
                style: textScaling.scaledBodyMedium(context),
              ),
              Text(
                '${plan.chaptersPerDay} chapters ${plan.frequency.displayName}',
                style: textScaling.scaledBodyMedium(context).copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionCard(BuildContext context, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: themeColor != null ? Border.all(
            color: themeColor.withValues(alpha: 0.3),
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
                  Icon(
                    Icons.library_books,
                    color: themeColor ?? Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'What to Read',
                    style: textScaling.scaledTitleMedium(context).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...BookCollection.values.map((collection) => RadioListTile<BookCollection>(
                title: Text(
                  collection.displayName,
                  style: textScaling.scaledBodyMedium(context),
                ),
                subtitle: Text(
                  collection.description,
                  style: textScaling.scaledBodySmall(context).copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                value: collection,
                groupValue: selectedCollection,
                activeColor: themeColor ?? Theme.of(context).colorScheme.primary,
                onChanged: (BookCollection? value) {
                  setState(() {
                    selectedCollection = value!;
                  });
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFrequencyCard(BuildContext context, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: themeColor != null ? Border.all(
            color: themeColor.withValues(alpha: 0.3),
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
                  Icon(
                    Icons.repeat,
                    color: themeColor ?? Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'How Often',
                    style: textScaling.scaledTitleMedium(context).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...ReadingFrequency.values.map((frequency) => RadioListTile<ReadingFrequency>(
                title: Text(
                  frequency.displayName,
                  style: textScaling.scaledBodyMedium(context),
                ),
                subtitle: Text(
                  frequency.description,
                  style: textScaling.scaledBodySmall(context).copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                value: frequency,
                groupValue: selectedFrequency,
                activeColor: themeColor ?? Theme.of(context).colorScheme.primary,
                onChanged: (ReadingFrequency? value) {
                  setState(() {
                    selectedFrequency = value!;
                  });
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChaptersCard(BuildContext context, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: themeColor != null ? Border.all(
            color: themeColor.withValues(alpha: 0.3),
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
                  Icon(
                    Icons.speed,
                    color: themeColor ?? Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reading Pace',
                    style: textScaling.scaledTitleMedium(context).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Chapters per reading session:',
                style: textScaling.scaledBodyMedium(context).copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: chaptersPerDay > 1 ? () {
                      setState(() {
                        chaptersPerDay--;
                      });
                    } : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Container(
                    width: 80,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: (themeColor ?? Theme.of(context).colorScheme.primary)
                            .withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      chaptersPerDay.toString(),
                      style: textScaling.scaledTitleMedium(context).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    onPressed: chaptersPerDay < 10 ? () {
                      setState(() {
                        chaptersPerDay++;
                      });
                    } : null,
                    icon: const Icon(Icons.add),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _getEstimatedTimeText(),
                      style: textScaling.scaledBodySmall(context).copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRemindersCard(BuildContext context, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: themeColor != null ? Border.all(
            color: themeColor.withValues(alpha: 0.3),
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
                  Icon(
                    Icons.notifications,
                    color: themeColor ?? Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reminders',
                    style: textScaling.scaledTitleMedium(context).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(
                  'Enable reading reminders',
                  style: textScaling.scaledBodyMedium(context),
                ),
                subtitle: Text(
                  'Get notified when it\'s time to read',
                  style: textScaling.scaledBodySmall(context).copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                value: remindersEnabled,
                activeColor: themeColor ?? Theme.of(context).colorScheme.primary,
                onChanged: (bool value) {
                  setState(() {
                    remindersEnabled = value;
                  });
                },
              ),
              if (remindersEnabled) ...[
                const SizedBox(height: 12),
                ListTile(
                  title: Text(
                    'Reminder time',
                    style: textScaling.scaledBodyMedium(context),
                  ),
                  subtitle: Text(
                    reminderTime?.format(context) ?? 'Tap to set time',
                    style: textScaling.scaledBodySmall(context).copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  trailing: const Icon(Icons.access_time),
                  onTap: _selectReminderTime,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getEstimatedTimeText() {
    final baseMinutes = chaptersPerDay * 4; // Roughly 4 minutes per chapter
    if (baseMinutes < 60) {
      return 'Est. $baseMinutes minutes reading time';
    } else {
      final hours = baseMinutes / 60;
      return 'Est. ${hours.toStringAsFixed(1)} hours reading time';
    }
  }

  Future<void> _selectReminderTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: reminderTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        reminderTime = picked;
      });
    }
  }

  void _createReadingPlan() {
    final plan = ReadingPlan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      collection: selectedCollection,
      frequency: selectedFrequency,
      chaptersPerDay: chaptersPerDay,
      remindersEnabled: remindersEnabled,
      reminderTime: reminderTime,
      progress: ReadingProgress.start(selectedCollection),
      createdAt: DateTime.now(),
    );

    ref.read(readingPlanProvider.notifier).createPlan(plan);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reading plan created successfully!'),
        backgroundColor: Colors.green,
      ),
    );
    
    Navigator.of(context).pop();
  }
}
