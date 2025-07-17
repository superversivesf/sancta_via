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
  // Form state for creating new plans
  String planName = '';
  BookCollection selectedCollection = BookCollection.wholeBible;
  ReadingFrequency selectedFrequency = ReadingFrequency.daily;
  Set<DayOfWeek> selectedDays = Set.from(DayOfWeek.values);
  int chaptersPerDay = 1;
  bool remindersEnabled = false;
  TimeOfDay? reminderTime;
  bool isCreatingPlan = false;
  late TextEditingController _planNameController;

  @override
  void initState() {
    super.initState();
    _planNameController = TextEditingController(text: planName);
  }

  @override
  void dispose() {
    _planNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = ref.watch(currentLiturgicalColorProvider);
    final colorIntensity = ref.watch(colorIntensityProvider);
    final textScaling = ref.watch(textScaleProvider);
    final activePlans = ref.watch(activeReadingPlansProvider);
    final completedPlans = ref.watch(completedReadingPlansProvider);
    final pausedPlans = ref.watch(pausedReadingPlansProvider);
    final canAddNew = ref.watch(canAddNewPlanProvider);
    
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
        actions: [
          if (canAddNew && !isCreatingPlan)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                setState(() {
                  isCreatingPlan = true;
                  _resetFormState();
                });
              },
              tooltip: 'Create New Plan',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isCreatingPlan) ...[
              // Plan creation form
              _buildCreatePlanForm(context, themeColor),
            ] else ...[
              // Plan management dashboard
              _buildPlanDashboard(context, activePlans, completedPlans, pausedPlans, themeColor, canAddNew),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlanDashboard(BuildContext context, List<ReadingPlan> activePlans, List<ReadingPlan> completedPlans, List<ReadingPlan> pausedPlans, Color? themeColor, bool canAddNew) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Column(
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
          'Manage your Bible reading journey with multiple simultaneous plans.',
          style: textScaling.scaledBodyLarge(context).copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 24),

        // Plan capacity indicator
        _buildPlanCapacityCard(context, activePlans.length, themeColor, canAddNew),
        const SizedBox(height: 24),

        // Active Plans
        if (activePlans.isNotEmpty) ...[
          _buildPlanSection(
            context,
            'Active Plans',
            activePlans,
            Icons.auto_stories,
            themeColor ?? Colors.green,
            _buildActivePlanCard,
          ),
          const SizedBox(height: 24),
        ],

        // Paused Plans
        if (pausedPlans.isNotEmpty) ...[
          _buildPlanSection(
            context,
            'Paused Plans',
            pausedPlans,
            Icons.pause_circle,
            Colors.orange,
            _buildPausedPlanCard,
          ),
          const SizedBox(height: 24),
        ],

        // Completed Plans
        if (completedPlans.isNotEmpty) ...[
          _buildPlanSection(
            context,
            'Completed Plans',
            completedPlans,
            Icons.celebration,
            Colors.green,
            _buildCompletedPlanCard,
          ),
          const SizedBox(height: 24),
        ],

        // Empty state
        if (activePlans.isEmpty && pausedPlans.isEmpty && completedPlans.isEmpty) ...[
          _buildEmptyState(context, themeColor),
        ],

        // Add new plan button (always visible)
        if (canAddNew)
          _buildAddNewPlanCard(context, themeColor),
      ],
    );
  }

  Widget _buildPlanCapacityCard(BuildContext context, int activePlanCount, Color? themeColor, bool canAddNew) {
    final textScaling = ref.watch(textScaleProvider);
    final remainingSlots = maxSimultaneousPlans - activePlanCount;
    
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
          child: Row(
            children: [
              Icon(
                Icons.dashboard,
                color: themeColor ?? Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plan Capacity',
                      style: textScaling.scaledTitleMedium(context).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$activePlanCount of $maxSimultaneousPlans simultaneous plans',
                      style: textScaling.scaledBodyMedium(context).copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: canAddNew ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  canAddNew ? '$remainingSlots slot${remainingSlots != 1 ? 's' : ''} left' : 'Full',
                  style: textScaling.scaledLabelMedium(context).copyWith(
                    color: canAddNew ? Colors.green.shade700 : Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanSection(
    BuildContext context,
    String title,
    List<ReadingPlan> plans,
    IconData icon,
    Color color,
    Widget Function(BuildContext, ReadingPlan, Color?) cardBuilder,
  ) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: textScaling.scaledTitleMedium(context).copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${plans.length}',
                style: textScaling.scaledLabelSmall(context).copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...plans.map((plan) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: cardBuilder(context, plan, color),
        )),
      ],
    );
  }

  Widget _buildActivePlanCard(BuildContext context, ReadingPlan plan, Color? themeColor) {
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: textScaling.scaledTitleMedium(context).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          plan.collection.displayName,
                          style: textScaling.scaledBodyMedium(context).copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handlePlanAction(plan, value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit Plan'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'pause',
                        child: Row(
                          children: [
                            Icon(Icons.pause, size: 18),
                            SizedBox(width: 8),
                            Text('Pause Plan'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'reset',
                        child: Row(
                          children: [
                            Icon(Icons.restart_alt, size: 18),
                            SizedBox(width: 8),
                            Text('Reset Progress'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete Plan', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Progress bar
              LinearProgressIndicator(
                value: plan.progressPercentage,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  themeColor ?? Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              
              // Plan details
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Progress: ${plan.progress.currentBook} ${plan.progress.currentChapter}',
                      style: textScaling.scaledBodySmall(context).copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${(plan.progressPercentage * 100).toStringAsFixed(1)}%',
                    style: textScaling.scaledBodySmall(context).copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${plan.chaptersPerDay} chapters • ${plan.scheduledDaysText}',
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

  Widget _buildPausedPlanCard(BuildContext context, ReadingPlan plan, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Card(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.pause_circle, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: textScaling.scaledTitleSmall(context).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${plan.collection.displayName} • ${(plan.progressPercentage * 100).toStringAsFixed(1)}% complete',
                      style: textScaling.scaledBodySmall(context).copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _handlePlanAction(plan, 'resume'),
                child: const Text('Resume'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedPlanCard(BuildContext context, ReadingPlan plan, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Card(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.celebration, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: textScaling.scaledTitleSmall(context).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${plan.collection.displayName} • Completed ${_formatDate(plan.completedAt)}',
                      style: textScaling.scaledBodySmall(context).copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _handlePlanAction(plan, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'restart',
                    child: Row(
                      children: [
                        Icon(Icons.replay, size: 18),
                        SizedBox(width: 8),
                        Text('Restart Plan'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete Plan', style: TextStyle(color: Colors.red)),
                      ],
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

  Widget _buildEmptyState(BuildContext context, Color? themeColor) {
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
          padding: const EdgeInsets.all(32),
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
                'No Reading Plans Yet',
                style: textScaling.scaledTitleLarge(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: themeColor?.withValues(alpha: 0.8) ?? 
                         Theme.of(context).colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Create your first reading plan to start your Bible reading journey with structure and guidance.',
                style: textScaling.scaledBodyLarge(context).copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddNewPlanCard(BuildContext context, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            isCreatingPlan = true;
            _resetFormState();
          });
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.3),
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.add,
                    color: themeColor ?? Theme.of(context).colorScheme.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create New Reading Plan',
                        style: textScaling.scaledTitleMedium(context).copyWith(
                          fontWeight: FontWeight.bold,
                          color: themeColor?.withValues(alpha: 0.8) ?? 
                                 Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add another Bible reading plan to your routine',
                        style: textScaling.scaledBodyMedium(context).copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: themeColor?.withValues(alpha: 0.6) ?? 
                         Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreatePlanForm(BuildContext context, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with back button
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  isCreatingPlan = false;
                });
              },
            ),
            Expanded(
              child: Text(
                'Create New Reading Plan',
                style: textScaling.scaledHeadlineSmall(context).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Plan Name
        _buildPlanNameCard(context, themeColor),
        const SizedBox(height: 16),

        // Book Collection Selection
        _buildCollectionCard(context, themeColor),
        const SizedBox(height: 16),

        // Schedule Selection
        _buildScheduleCard(context, themeColor),
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
            onPressed: _canCreatePlan() ? _createReadingPlan : null,
            icon: const Icon(Icons.create),
            label: Text(
              'Create Plan',
              style: textScaling.scaledBodyLarge(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor ?? Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanNameCard(BuildContext context, Color? themeColor) {
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
                    Icons.edit,
                    color: themeColor ?? Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Plan Name',
                    style: textScaling.scaledTitleMedium(context).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _planNameController,
                decoration: InputDecoration(
                  hintText: planName.isEmpty ? 'Enter a name or leave blank for default (${selectedCollection.displayName})' : 'Enter a name for your reading plan...',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    planName = value;
                  });
                },
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
                    // Auto-fill plan name if it's empty
                    if (planName.trim().isEmpty) {
                      planName = value.displayName;
                      _planNameController.text = planName; // Update the text field
                    }
                  });
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleCard(BuildContext context, Color? themeColor) {
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
                    Icons.calendar_today,
                    color: themeColor ?? Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reading Schedule',
                    style: textScaling.scaledTitleMedium(context).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Frequency presets
              Text(
                'Quick Presets:',
                style: textScaling.scaledBodyMedium(context).copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
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
                    selectedDays = DayOfWeek.fromFrequency(value).toSet();
                  });
                },
              )),
              
              const SizedBox(height: 16),
              
              // Custom day selection
              Text(
                'Custom Days (tap to toggle):',
                style: textScaling.scaledBodyMedium(context).copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: DayOfWeek.values.map((day) {
                  final isSelected = selectedDays.contains(day);
                  return FilterChip(
                    label: Text(day.shortName),
                    selected: isSelected,
                    selectedColor: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.2),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          selectedDays.add(day);
                        } else {
                          selectedDays.remove(day);
                        }
                        // Update frequency to custom if needed
                        selectedFrequency = ReadingFrequency.daily; // Keep as daily for simplicity
                      });
                    },
                  );
                }).toList(),
              ),
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

  void _resetFormState() {
    planName = '';
    _planNameController.clear();
    selectedCollection = BookCollection.wholeBible;
    selectedFrequency = ReadingFrequency.daily;
    selectedDays = Set.from(DayOfWeek.values);
    chaptersPerDay = 1;
    remindersEnabled = false;
    reminderTime = null;
  }

  bool _canCreatePlan() {
    // Allow creation if name is not empty OR if we can auto-generate from collection
    final effectiveName = planName.trim().isNotEmpty ? planName.trim() : selectedCollection.displayName;
    return effectiveName.isNotEmpty && selectedDays.isNotEmpty;
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.day}/${date.month}/${date.year}';
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
    if (!_canCreatePlan()) return;
    
    // Use entered name or default to collection name
    final effectiveName = planName.trim().isNotEmpty ? planName.trim() : selectedCollection.displayName;
    
    final plan = ReadingPlan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: effectiveName,
      collection: selectedCollection,
      frequency: selectedFrequency,
      scheduledDays: selectedDays,
      chaptersPerDay: chaptersPerDay,
      remindersEnabled: remindersEnabled,
      reminderTime: reminderTime,
      progress: ReadingProgress.start(selectedCollection),
      createdAt: DateTime.now(),
    );

    try {
      ref.read(readingPlanManagerProvider.notifier).createPlan(plan);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reading plan "${plan.name}" created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      setState(() {
        isCreatingPlan = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating plan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handlePlanAction(ReadingPlan plan, String action) {
    switch (action) {
      case 'edit':
        // TODO: Implement edit plan functionality
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Edit plan functionality coming soon!')),
        );
        break;
      case 'pause':
        ref.read(readingPlanManagerProvider.notifier).pausePlan(plan.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Plan "${plan.name}" paused')),
        );
        break;
      case 'resume':
        ref.read(readingPlanManagerProvider.notifier).resumePlan(plan.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Plan "${plan.name}" resumed')),
        );
        break;
      case 'reset':
        _showResetDialog(plan);
        break;
      case 'restart':
        _showRestartDialog(plan);
        break;
      case 'delete':
        _showDeleteDialog(plan);
        break;
    }
  }

  void _showResetDialog(ReadingPlan plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Progress'),
        content: Text(
          'Reset the progress for "${plan.name}" back to the beginning? All progress will be lost.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(readingPlanManagerProvider.notifier).resetProgress(plan.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Progress reset for "${plan.name}"')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showRestartDialog(ReadingPlan plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Plan'),
        content: Text(
          'Restart "${plan.name}" from the beginning as an active plan?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(readingPlanManagerProvider.notifier).resetProgress(plan.id);
              ref.read(readingPlanManagerProvider.notifier).resumePlan(plan.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Plan "${plan.name}" restarted!')),
              );
            },
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(ReadingPlan plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plan'),
        content: Text(
          'Permanently delete "${plan.name}"? This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(readingPlanManagerProvider.notifier).removePlan(plan.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Plan "${plan.name}" deleted')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}