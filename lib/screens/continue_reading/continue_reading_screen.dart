import 'package:flutter/material.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import '../../providers/text_scaling_provider.dart';
import '../../providers/reading_plan_provider.dart';
import '../../models/reading_plan.dart';
import '../chapter/chapter_reading_screen.dart';
import '../reading_plan/reading_plan_screen.dart';

class ContinueReadingScreen extends ConsumerWidget {
  const ContinueReadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentColor = ref.watch(currentLiturgicalColorProvider);
    final colorIntensity = ref.watch(colorIntensityProvider);
    final textScaling = ref.watch(textScaleProvider);
    final currentPlan = ref.watch(currentReadingPlanProvider);
    final shouldReadToday = ref.watch(shouldReadTodayProvider);
    final todaysReading = ref.watch(todaysReadingProvider);
    
    // Parse liturgical color and convert to Flutter color
    final liturgicalColor = currentColor != null 
        ? LiturgicalColor.fromString(currentColor)
        : null;
    final themeColor = liturgicalColor?.toFlutterColor(colorIntensity);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Continue Reading',
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
              'Pick up where you left off',
              style: textScaling.scaledHeadlineSmall(context).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Continue your reading journey with your established plan.',
              style: textScaling.scaledBodyLarge(context).copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),

            // Content based on reading plan status
            if (currentPlan == null) ...[
              _buildNoReadingPlanCard(context, ref, themeColor),
            ] else if (currentPlan.isCompleted) ...[
              _buildCompletedPlanCard(context, ref, currentPlan, themeColor),
            ] else if (shouldReadToday && todaysReading != null) ...[
              _buildTodaysReadingCard(context, ref, todaysReading, themeColor),
              const SizedBox(height: 16),
              _buildProgressCard(context, ref, currentPlan, themeColor),
            ] else ...[
              _buildNotScheduledCard(context, ref, currentPlan, themeColor),
              const SizedBox(height: 16),
              _buildProgressCard(context, ref, currentPlan, themeColor),
            ],

            const SizedBox(height: 24),
            _buildQuickActionsCard(context, ref, currentPlan, themeColor),
          ],
        ),
      ),
    );
  }

  Widget _buildNoReadingPlanCard(BuildContext context, WidgetRef ref, Color? themeColor) {
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
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.auto_stories_outlined,
                size: textScaling.scaleFactor * 64,
                color: themeColor?.withValues(alpha: 0.7) ?? 
                       Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 16),
              Text(
                'No Reading Plan Set',
                style: textScaling.scaledTitleLarge(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: themeColor?.withValues(alpha: 0.8) ?? 
                         Theme.of(context).colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Create a reading plan to get structured daily reading recommendations and track your progress through the Bible.',
                style: textScaling.scaledBodyLarge(context).copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ReadingPlanScreen()),
                  );
                },
                icon: const Icon(Icons.create),
                label: Text(
                  'Create Reading Plan',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodaysReadingCard(BuildContext context, WidgetRef ref, TodaysReading todaysReading, Color? themeColor) {
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (themeColor ?? Theme.of(context).colorScheme.primary)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.today,
                      color: themeColor ?? Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Today\'s Reading',
                      style: textScaling.scaledTitleMedium(context).copyWith(
                        fontWeight: FontWeight.bold,
                        color: themeColor?.withValues(alpha: 0.8) ?? 
                               Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (themeColor ?? Theme.of(context).colorScheme.primary)
                      .withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (themeColor ?? Theme.of(context).colorScheme.primary)
                        .withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      todaysReading.displayText,
                      style: textScaling.scaledHeadlineSmall(context).copyWith(
                        fontWeight: FontWeight.bold,
                        color: themeColor?.withValues(alpha: 0.9) ?? 
                               Theme.of(context).colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      todaysReading.chaptersToRead == 1 
                        ? '1 chapter to read today'
                        : '${todaysReading.chaptersToRead} chapters to read today',
                      style: textScaling.scaledBodyMedium(context).copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Action buttons for each chapter
              if (todaysReading.chaptersToRead == 1) ...[
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToChapter(
                      context, 
                      todaysReading.book, 
                      todaysReading.startChapter
                    ),
                    icon: const Icon(Icons.menu_book),
                    label: Text(
                      'Start Reading',
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
              ] else ...[
                Text(
                  'Chapters to read:',
                  style: textScaling.scaledTitleSmall(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: todaysReading.chapterRange.map((chapter) {
                    return ElevatedButton(
                      onPressed: () => _navigateToChapter(
                        context, 
                        todaysReading.book, 
                        chapter
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (themeColor ?? Theme.of(context).colorScheme.primary)
                            .withValues(alpha: 0.1),
                        foregroundColor: themeColor ?? Theme.of(context).colorScheme.primary,
                        side: BorderSide(
                          color: (themeColor ?? Theme.of(context).colorScheme.primary)
                              .withValues(alpha: 0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Chapter $chapter'),
                    );
                  }).toList(),
                ),
              ],
              
              const SizedBox(height: 16),
              
              // Mark complete button
              Center(
                child: TextButton.icon(
                  onPressed: () => _markTodayComplete(context, ref),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    'Mark Today\'s Reading Complete',
                    style: textScaling.scaledBodyMedium(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotScheduledCard(BuildContext context, WidgetRef ref, ReadingPlan plan, Color? themeColor) {
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Not Scheduled for Today',
                      style: textScaling.scaledTitleMedium(context).copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Based on your reading schedule (${plan.frequency.displayName}), you\'re not scheduled to read today. You can still continue with your plan or read ahead if you\'d like.',
                style: textScaling.scaledBodyMedium(context).copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToChapter(
                        context, 
                        plan.progress.currentBook, 
                        plan.progress.currentChapter
                      ),
                      icon: const Icon(Icons.menu_book),
                      label: Text('Read Anyway'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (themeColor ?? Theme.of(context).colorScheme.primary)
                            .withValues(alpha: 0.1),
                        foregroundColor: themeColor ?? Theme.of(context).colorScheme.primary,
                        side: BorderSide(
                          color: (themeColor ?? Theme.of(context).colorScheme.primary)
                              .withValues(alpha: 0.3),
                        ),
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

  Widget _buildCompletedPlanCard(BuildContext context, WidgetRef ref, ReadingPlan plan, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.celebration,
                size: textScaling.scaleFactor * 64,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              Text(
                'Congratulations!',
                style: textScaling.scaledTitleLarge(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You\'ve completed your ${plan.collection.displayName} reading plan!',
                style: textScaling.scaledBodyLarge(context).copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ReadingPlanScreen()),
                        );
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text('Start New Plan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref.read(readingPlanProvider.notifier).resetProgress();
                      },
                      icon: const Icon(Icons.replay),
                      label: Text('Restart Plan'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: BorderSide(color: Colors.green),
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

  Widget _buildProgressCard(BuildContext context, WidgetRef ref, ReadingPlan plan, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    final progressPercentage = plan.progressPercentage;
    
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
                    Icons.trending_up,
                    color: themeColor ?? Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reading Progress',
                    style: textScaling.scaledTitleMedium(context).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Progress bar
              LinearProgressIndicator(
                value: progressPercentage,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  themeColor ?? Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(progressPercentage * 100).toStringAsFixed(1)}% complete',
                style: textScaling.scaledBodySmall(context).copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              
              const SizedBox(height: 12),
              Text(
                'Currently reading: ${plan.progress.currentBook} ${plan.progress.currentChapter}',
                style: textScaling.scaledBodyMedium(context).copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Plan: ${plan.collection.displayName} • ${plan.frequency.displayName}',
                style: textScaling.scaledBodySmall(context).copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard(BuildContext context, WidgetRef ref, ReadingPlan? plan, Color? themeColor) {
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
                    Icons.flash_on,
                    color: themeColor ?? Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Quick Actions',
                    style: textScaling.scaledTitleMedium(context).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              if (plan != null) ...[
                ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Modify Reading Plan'),
                  subtitle: Text('Update schedule, pace, or book selection'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ReadingPlanScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.fast_forward),
                  title: Text('Skip to Next Section'),
                  subtitle: Text('Jump ahead in your reading plan'),
                  onTap: () => _showSkipDialog(context, ref),
                ),
                ListTile(
                  leading: Icon(Icons.restart_alt),
                  title: Text('Reset Progress'),
                  subtitle: Text('Start your current plan from the beginning'),
                  onTap: () => _showResetDialog(context, ref),
                ),
              ] else ...[
                ListTile(
                  leading: Icon(Icons.add),
                  title: Text('Create Reading Plan'),
                  subtitle: Text('Get started with structured Bible reading'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ReadingPlanScreen()),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToChapter(BuildContext context, String book, int chapter) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChapterReadingScreen(
          bookName: book,
          chapter: chapter,
        ),
      ),
    );
  }

  void _markTodayComplete(BuildContext context, WidgetRef ref) {
    ref.read(readingPlanProvider.notifier).completeToday();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Great job! Today\'s reading marked as complete.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showSkipDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip to Next Section'),
        content: const Text(
          'This will advance your reading plan to the next book or section. Are you sure you want to skip ahead?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implementation would go here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Skip functionality coming soon!')),
              );
            },
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Progress'),
        content: const Text(
          'This will reset your reading plan progress back to the beginning. All progress will be lost. Are you sure?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(readingPlanProvider.notifier).resetProgress();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reading plan progress has been reset.'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
