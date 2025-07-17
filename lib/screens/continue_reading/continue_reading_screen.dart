import 'package:flutter/material.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:go_router/go_router.dart';

import '../../providers/text_scaling_provider.dart';
import '../../providers/reading_plan_provider.dart';
import '../../models/reading_plan.dart';

class ContinueReadingScreen extends ConsumerWidget {
  const ContinueReadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentColor = ref.watch(currentLiturgicalColorProvider);
    final colorIntensity = ref.watch(colorIntensityProvider);
    final textScaling = ref.watch(textScaleProvider);
    final activePlans = ref.watch(activeReadingPlansProvider);
    final todaysPlansOrdered = ref.watch(todaysPlansOrderedProvider);
    final shouldReadToday = ref.watch(shouldReadTodayProvider);
    
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
              'Today\'s Reading Plans',
              style: textScaling.scaledHeadlineSmall(context).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Continue your reading journey across all your active plans.',
              style: textScaling.scaledBodyLarge(context).copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),

            // Content based on reading plan status
            if (activePlans.isEmpty) ...[
              _buildNoReadingPlansCard(context, ref, themeColor),
            ] else if (!shouldReadToday) ...[
              _buildNoReadingTodayCard(context, ref, activePlans, themeColor),
            ] else ...[
              // Today's reading plans
              _buildTodaysReadingPlans(context, ref, todaysPlansOrdered, themeColor),
              const SizedBox(height: 24),
              
              // Overall progress summary
              _buildProgressSummaryCard(context, ref, activePlans, themeColor),
            ],

            const SizedBox(height: 24),
            _buildQuickActionsCard(context, ref, activePlans, themeColor),
          ],
        ),
      ),
    );
  }

  Widget _buildNoReadingPlansCard(BuildContext context, WidgetRef ref, Color? themeColor) {
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
                'No Reading Plans Set',
                style: textScaling.scaledTitleLarge(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: themeColor?.withValues(alpha: 0.8) ?? 
                         Theme.of(context).colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Create reading plans to get structured daily reading recommendations and track your progress through the Bible.',
                style: textScaling.scaledBodyLarge(context).copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  context.push('/reading-plan');
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

  Widget _buildNoReadingTodayCard(BuildContext context, WidgetRef ref, List<ReadingPlan> activePlans, Color? themeColor) {
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
            children: [
              const Icon(
                Icons.schedule,
                color: Colors.orange,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'No Plans Scheduled for Today',
                style: textScaling.scaledTitleLarge(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Based on your reading schedules, none of your ${activePlans.length} active plan${activePlans.length > 1 ? 's are' : ' is'} scheduled for today.',
                style: textScaling.scaledBodyLarge(context).copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'You can still read ahead if you\'d like!',
                style: textScaling.scaledBodyMedium(context).copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodaysReadingPlans(BuildContext context, WidgetRef ref, List<ReadingPlan> todaysPlans, Color? themeColor) {
    if (todaysPlans.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: todaysPlans.asMap().entries.map((entry) {
        final index = entry.key;
        final plan = entry.value;
        final isLastItem = index == todaysPlans.length - 1;
        
        return Padding(
          padding: EdgeInsets.only(bottom: isLastItem ? 0 : 16),
          child: _buildPlanReadingCard(context, ref, plan, themeColor),
        );
      }).toList(),
    );
  }

  Widget _buildPlanReadingCard(BuildContext context, WidgetRef ref, ReadingPlan plan, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    final todaysReading = TodaysReading.fromPlan(plan);
    
    // Different styling for read vs unread plans
    final isRead = plan.hasReadToday;
    final cardColor = isRead 
      ? Colors.green.withValues(alpha: 0.1)
      : (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.05);
    final borderColor = isRead 
      ? Colors.green.withValues(alpha: 0.3)
      : (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.3);
    final iconColor = isRead 
      ? Colors.green
      : (themeColor ?? Theme.of(context).colorScheme.primary);
    
    return Card(
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plan header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isRead ? Icons.check_circle : Icons.menu_book,
                      color: iconColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: textScaling.scaledTitleMedium(context).copyWith(
                            fontWeight: FontWeight.bold,
                            color: iconColor.withValues(alpha: 0.9),
                          ),
                        ),
                        Text(
                          plan.collection.displayName,
                          style: textScaling.scaledBodySmall(context).copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isRead) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Completed',
                        style: textScaling.scaledLabelSmall(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Reading details
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      todaysReading.displayText,
                      style: textScaling.scaledTitleMedium(context).copyWith(
                        fontWeight: FontWeight.bold,
                        color: iconColor.withValues(alpha: 0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      todaysReading.chaptersToRead == 1 
                        ? '1 chapter to read'
                        : '${todaysReading.chaptersToRead} chapters to read',
                      style: textScaling.scaledBodySmall(context).copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Action buttons
              if (!isRead) ...[
                // Reading buttons for unread plans
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
                        style: textScaling.scaledBodyMedium(context).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: iconColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Multiple chapters
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...todaysReading.chapterRange.map((chapter) {
                        return ElevatedButton(
                          onPressed: () => _navigateToChapter(
                            context, 
                            todaysReading.book, 
                            chapter
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: iconColor.withValues(alpha: 0.1),
                            foregroundColor: iconColor,
                            side: BorderSide(
                              color: iconColor.withValues(alpha: 0.3),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text('Ch. $chapter'),
                        );
                      }),
                    ],
                  ),
                ],
                
                const SizedBox(height: 12),
                
                // Mark complete button
                Center(
                  child: TextButton.icon(
                    onPressed: () => _markPlanComplete(context, ref, plan.id),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      'Mark as Complete',
                      style: textScaling.scaledBodySmall(context),
                    ),
                  ),
                ),
              ] else ...[
                // Already read - show summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.celebration,
                      color: Colors.green,
                      size: textScaling.scaleFactor * 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Great job! Reading completed for today.',
                      style: textScaling.scaledBodyMedium(context).copyWith(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSummaryCard(BuildContext context, WidgetRef ref, List<ReadingPlan> activePlans, Color? themeColor) {
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
                    Icons.trending_up,
                    color: themeColor ?? Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Active Reading Plans Summary',
                    style: textScaling.scaledTitleMedium(context).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              ...activePlans.map((plan) {
                final progressPercentage = plan.progressPercentage;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              plan.name,
                              style: textScaling.scaledBodyMedium(context).copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '${(progressPercentage * 100).toStringAsFixed(1)}%',
                            style: textScaling.scaledBodySmall(context).copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: progressPercentage,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          themeColor ?? Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${plan.progress.currentBook} ${plan.progress.currentChapter} • ${plan.scheduledDaysText}',
                        style: textScaling.scaledBodySmall(context).copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
    );
  }

  Widget _buildQuickActionsCard(BuildContext context, WidgetRef ref, List<ReadingPlan> activePlans, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    final canAddNew = ref.watch(canAddNewPlanProvider);
    
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
              
              if (canAddNew) ...[
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Add New Reading Plan'),
                  subtitle: Text('${maxSimultaneousPlans - activePlans.length} more plan${maxSimultaneousPlans - activePlans.length != 1 ? 's' : ''} allowed'),
                  onTap: () {
                    context.push('/reading-plan');
                  },
                ),
              ] else ...[
                ListTile(
                  leading: Icon(Icons.info, color: Colors.orange.shade700),
                  title: Text('Maximum Plans Reached', style: TextStyle(color: Colors.orange.shade700)),
                  subtitle: Text('You have the maximum of $maxSimultaneousPlans simultaneous plans'),
                ),
              ],
              
              if (activePlans.isNotEmpty) ...[
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Manage Reading Plans'),
                  subtitle: const Text('Edit schedules, settings, or pause plans'),
                  onTap: () {
                    context.push('/reading-plan');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Reset Daily Status'),
                  subtitle: const Text('Mark all plans as unread for today'),
                  onTap: () => _showResetDailyDialog(context, ref),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToChapter(BuildContext context, String book, int chapter) {
    context.push('/chapter/${Uri.encodeComponent(book)}/$chapter');
  }

  void _markPlanComplete(BuildContext context, WidgetRef ref, String planId) {
    ref.read(readingPlanManagerProvider.notifier).markPlanReadToday(planId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Great job! Plan marked as complete for today.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showResetDailyDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Daily Status'),
        content: const Text(
          'This will mark all reading plans as unread for today. Are you sure?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(readingPlanManagerProvider.notifier).resetDailyStatus();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Daily reading status has been reset for all plans.'),
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