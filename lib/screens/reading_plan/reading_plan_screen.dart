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
    final manager = ref.watch(readingPlanManagerProvider);
    
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
          if (manager.canAddNewPlan() && !isCreatingPlan)
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
              _buildPlanDashboard(context, manager, themeColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlanDashboard(BuildContext context, ReadingPlanManager manager, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);

    final completedPlans = manager.completedPlans;
    final pausedPlans = manager.pausedPlans;
    final canAddNew = manager.canAddNewPlan();
    
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
          'Simple Bible reading plans. Read as much or as little as you want each day.',
          style: textScaling.scaledBodyLarge(context).copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 24),

        // Reading status for today
        _buildTodayStatusCard(context, manager, themeColor),
        const SizedBox(height: 24),

        // Plan capacity indicator
        _buildPlanCapacityCard(context, manager.activePlans.length, themeColor, canAddNew),
        const SizedBox(height: 24),

        // Active Plans
        if (manager.activePlans.isNotEmpty) ...[
          _buildPlanSection(
            context,
            'Active Plans',
            manager.activePlans,
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
            themeColor ?? Colors.green,
            _buildCompletedPlanCard,
          ),
          const SizedBox(height: 24),
        ],

        // Empty state
        if (manager.activePlans.isEmpty && pausedPlans.isEmpty && completedPlans.isEmpty) ...[
          _buildEmptyState(context, themeColor),
        ],

        // Add new plan button (always visible)
        if (canAddNew)
          _buildAddNewPlanCard(context, themeColor),
      ],
    );
  }

  Widget _buildTodayStatusCard(BuildContext context, ReadingPlanManager manager, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    final hasReadToday = manager.hasReadAnythingToday;
    
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
                      hasReadToday ? 'You\'ve read today! 📖✅' : 'Ready to read today?',
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
                        : 'Pick any plan below and read the next chapter to get started.',
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
                  color: canAddNew ? (themeColor ?? Colors.green).withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  canAddNew ? '$remainingSlots slot${remainingSlots != 1 ? 's' : ''} left' : 'Full',
                  style: textScaling.scaledLabelMedium(context).copyWith(
                    color: canAddNew ? (themeColor ?? Colors.green).withValues(alpha: 0.8) : Colors.orange.shade700,
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
              
              // Next chapter to read
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Next chapter to read:',
                      style: textScaling.scaledBodySmall(context).copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.nextChapterText,
                      style: textScaling.scaledTitleLarge(context).copyWith(
                        fontWeight: FontWeight.bold,
                        color: themeColor ?? Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
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
              const Icon(Icons.pause_circle, color: Colors.orange),
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
          color: (themeColor ?? Colors.green).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (themeColor ?? Colors.green).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.celebration, color: themeColor ?? Colors.green),
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
                'Create reading plans to track your progress through different parts of the Bible. Read at your own pace!',
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

  void _resetFormState() {
    planName = '';
    _planNameController.clear();
    selectedCollection = BookCollection.wholeBible;
  }

  bool _canCreatePlan() {
    // Allow creation if name is not empty OR if we can auto-generate from collection
    final effectiveName = planName.trim().isNotEmpty ? planName.trim() : selectedCollection.displayName;
    return effectiveName.isNotEmpty;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _createReadingPlan() {
    if (!_canCreatePlan()) return;
    
    // Use entered name or default to collection name
    final effectiveName = planName.trim().isNotEmpty ? planName.trim() : selectedCollection.displayName;
    
    final plan = ReadingPlan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: effectiveName,
      collection: selectedCollection,
      progress: ReadingProgress.start(selectedCollection),
      createdAt: DateTime.now(),
    );

    try {
      // Get the current liturgical color
      final currentColor = ref.read(currentLiturgicalColorProvider);
      final colorIntensity = ref.read(colorIntensityProvider);
      final liturgicalColor = currentColor != null 
          ? LiturgicalColor.fromString(currentColor)
          : null;
      final themeColor = liturgicalColor?.toFlutterColor(colorIntensity);
      
      ref.read(readingPlanManagerProvider.notifier).createPlan(plan, successColor: themeColor);
      
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
    // Get the current liturgical color for success messages
    final currentColor = ref.read(currentLiturgicalColorProvider);
    final colorIntensity = ref.read(colorIntensityProvider);
    final liturgicalColor = currentColor != null 
        ? LiturgicalColor.fromString(currentColor)
        : null;
    final themeColor = liturgicalColor?.toFlutterColor(colorIntensity);
    
    switch (action) {
      case 'pause':
        ref.read(readingPlanManagerProvider.notifier).pausePlan(plan.id, successColor: themeColor);
        break;
      case 'resume':
        ref.read(readingPlanManagerProvider.notifier).resumePlan(plan.id, successColor: themeColor);
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
              // Get the current liturgical color for success message
              final currentColor = ref.read(currentLiturgicalColorProvider);
              final colorIntensity = ref.read(colorIntensityProvider);
              final liturgicalColor = currentColor != null 
                  ? LiturgicalColor.fromString(currentColor)
                  : null;
              final themeColor = liturgicalColor?.toFlutterColor(colorIntensity);
              
              ref.read(readingPlanManagerProvider.notifier).resetProgress(plan.id, successColor: themeColor);
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
              // Get the current liturgical color for success messages
              final currentColor = ref.read(currentLiturgicalColorProvider);
              final colorIntensity = ref.read(colorIntensityProvider);
              final liturgicalColor = currentColor != null 
                  ? LiturgicalColor.fromString(currentColor)
                  : null;
              final themeColor = liturgicalColor?.toFlutterColor(colorIntensity);
              
              ref.read(readingPlanManagerProvider.notifier).resetProgress(plan.id, successColor: themeColor);
              ref.read(readingPlanManagerProvider.notifier).resumePlan(plan.id, successColor: themeColor);
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
              // Get the current liturgical color for success message
              final currentColor = ref.read(currentLiturgicalColorProvider);
              final colorIntensity = ref.read(colorIntensityProvider);
              final liturgicalColor = currentColor != null 
                  ? LiturgicalColor.fromString(currentColor)
                  : null;
              final themeColor = liturgicalColor?.toFlutterColor(colorIntensity);
              
              ref.read(readingPlanManagerProvider.notifier).removePlan(plan.id, successColor: themeColor);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
