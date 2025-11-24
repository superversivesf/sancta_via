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
    final hasReadToday = ref.watch(hasReadTodayProvider);
    
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
      body: SafeArea(
        top: false, // Let AppBar handle top
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Header
            Text(
              'Your Reading Plans',
              style: textScaling.scaledHeadlineSmall(context).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick any plan and read the next chapter. Read as much or as little as you want!',
              style: textScaling.scaledBodyLarge(context).copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),

            // Reading status for today
            _buildTodayStatusCard(context, ref, hasReadToday, themeColor),
            const SizedBox(height: 24),

            // Content based on reading plan status
            if (activePlans.isEmpty) ...[
              _buildNoReadingPlansCard(context, ref, themeColor),
            ] else ...[
              // Active reading plans
              _buildActiveReadingPlans(context, ref, activePlans, themeColor),
              const SizedBox(height: 24),
              
              // Overall progress summary
              _buildProgressSummaryCard(context, ref, activePlans, themeColor),
            ],

            const SizedBox(height: 24),
            _buildQuickActionsCard(context, ref, activePlans, themeColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayStatusCard(BuildContext context, WidgetRef ref, bool hasReadToday, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Card(
      child: Container(
        decoration: BoxDecoration(
          color: hasReadToday 
            ? (themeColor ?? Colors.green).withValues(alpha: 0.1)
            : (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasReadToday 
              ? (themeColor ?? Colors.green).withValues(alpha: 0.3)
              : (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                hasReadToday ? Icons.check_circle : Icons.menu_book,
                color: hasReadToday 
                  ? (themeColor ?? Colors.green)
                  : themeColor ?? Theme.of(context).colorScheme.primary,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasReadToday ? 'You\'ve read today! 📖' : 'Ready to read today?',
                      style: textScaling.scaledTitleMedium(context).copyWith(
                        fontWeight: FontWeight.bold,
                        color: hasReadToday 
                          ? (themeColor ?? Colors.green).withValues(alpha: 0.9)
                          : (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.9),
                      ),
                    ),
                    Text(
                      hasReadToday 
                        ? 'Great job! You can keep reading if you want to get ahead.'
                        : 'Pick any reading plan below and start with the next chapter.',
                      style: textScaling.scaledBodyMedium(context).copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                'Create reading plans to track your progress through different parts of the Bible. Read at your own pace!',
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
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveReadingPlans(BuildContext context, WidgetRef ref, List<ReadingPlan> activePlans, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header for multiple plans
        if (activePlans.length > 1) ...[
          Text(
            'Your Active Reading Plans',
            style: textScaling.scaledTitleLarge(context).copyWith(
              fontWeight: FontWeight.bold,
              color: themeColor ?? Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose any plan to continue reading:',
            style: textScaling.scaledBodyMedium(context).copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
        ],
        
        // Individual plan cards with more spacing
        ...activePlans.map((plan) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPlanReadingCard(context, ref, plan, themeColor),
              const SizedBox(height: 24), // Consistent spacing between all plans
            ],
          );
        }),
      ],
    );
  }

  Widget _buildPlanReadingCard(BuildContext context, WidgetRef ref, ReadingPlan plan, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    final completionColor = themeColor ?? Theme.of(context).colorScheme.primary;
    
    return Card(
      elevation: 4, // Increased elevation for better separation
      child: Container(
        decoration: BoxDecoration(
          color: completionColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: completionColor.withValues(alpha: 0.4), // Slightly stronger border
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20), // Increased padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plan title banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: completionColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: completionColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: completionColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.menu_book,
                        color: completionColor,
                        size: 18,
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
                              color: completionColor.withValues(alpha: 0.95),
                            ),
                          ),
                          Text(
                            plan.collection.displayName,
                            style: textScaling.scaledBodySmall(context).copyWith(
                              color: completionColor.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Progress percentage
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: completionColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(plan.progressPercentage * 100).toStringAsFixed(1)}%',
                        style: textScaling.scaledLabelMedium(context).copyWith(
                          color: completionColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Next chapter to read - clickable to start reading
              InkWell(
                onTap: () => _navigateToChapter(
                  context, 
                  plan.progress.currentBook, 
                  plan.progress.currentChapter
                ),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: completionColor.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Next chapter to read:',
                        style: textScaling.scaledBodyMedium(context).copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.menu_book,
                            size: 28,
                            color: completionColor.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            plan.nextChapterText,
                            style: textScaling.scaledTitleLarge(context).copyWith(
                              fontWeight: FontWeight.bold,
                              color: completionColor.withValues(alpha: 0.9),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to start reading',
                        style: textScaling.scaledBodySmall(context).copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Progress bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reading Progress',
                    style: textScaling.scaledBodyMedium(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: completionColor.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: plan.progressPercentage,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(completionColor),
                    minHeight: 6,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Currently at: ${plan.progress.currentBook} ${plan.progress.currentChapter}',
                    style: textScaling.scaledBodySmall(context).copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Quick action button
              Center(
                child: ElevatedButton.icon(
                  onPressed: () => _advancePlan(context, ref, plan.id, themeColor),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text(
                    'Mark as Read & Advance',
                    style: textScaling.scaledBodyMedium(context).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: completionColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
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
                    'Reading Progress Summary',
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
                        'Currently at: ${plan.progress.currentBook} ${plan.progress.currentChapter}',
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
    final manager = ref.watch(readingPlanManagerProvider);
    final canAddNew = manager.canAddNewPlan();
    
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
                  subtitle: const Text('Pause, reset, or delete plans'),
                  onTap: () {
                    context.push('/reading-plan');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Reset Daily Status'),
                  subtitle: const Text('Mark as not read for today'),
                  onTap: () => _showResetDailyDialog(context, ref),
                ),
              ],
              
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Bible Lookup'),
                subtitle: const Text('Read any chapter directly'),
                onTap: () {
                  context.push('/bible-lookup');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToChapter(BuildContext context, String book, int chapter) {
    context.push('/chapter/${Uri.encodeComponent(book)}/$chapter');
  }

  void _advancePlan(BuildContext context, WidgetRef ref, String planId, Color? themeColor) {
    ref.read(readingPlanManagerProvider.notifier).advancePlan(planId, successColor: themeColor);
    // Note: Success message is now handled by the UserMessageService with liturgical color
  }

  void _showResetDailyDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Daily Status'),
        content: const Text(
          'This will mark you as not having read today. Are you sure?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Get the current liturgical color for success message
              final currentColor = ref.read(currentLiturgicalColorProvider);
              final colorIntensity = ref.read(colorIntensityProvider);
              final liturgicalColor = currentColor != null 
                  ? LiturgicalColor.fromString(currentColor)
                  : null;
              final themeColor = liturgicalColor?.toFlutterColor(colorIntensity);
              
              ref.read(readingPlanManagerProvider.notifier).resetDailyStatus(successColor: themeColor);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
