import 'package:flutter/material.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:go_router/go_router.dart';

import '../../providers/text_scaling_provider.dart';
import '../../providers/reading_plan_provider.dart';
import '../../models/reading_plan.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentDay = ref.watch(currentLiturgicalDayProvider);
    final currentColor = ref.watch(currentLiturgicalColorProvider);
    final colorIntensity = ref.watch(colorIntensityProvider);
    final textScaling = ref.watch(textScaleProvider);
    
    // Parse liturgical color and convert to Flutter color
    final liturgicalColor = currentColor != null 
        ? LiturgicalColor.fromString(currentColor)
        : null;
    final themeColor = liturgicalColor?.toFlutterColor(colorIntensity);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bible Reading App',
          style: textScaling.scaledTitleLarge(context),
        ),
        backgroundColor: themeColor?.withValues(alpha: 0.1),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.push('/settings');
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false, // Let AppBar handle top
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Liturgical Day Card (keep this - it's beautiful!)
            if (currentDay != null) ...[
              Card(
                margin: const EdgeInsets.only(bottom: 24),
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
                            if (themeColor != null) ...[
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: themeColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Text(
                                'Today\'s Liturgical Season',
                                style: textScaling.scaledTitleMedium(context).copyWith(
                                  color: themeColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentDay.season,
                          style: textScaling.scaledHeadlineSmall(context).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (currentDay.celebration.name.isNotEmpty && 
                            currentDay.celebration.name != currentDay.season) ...[
                          const SizedBox(height: 4),
                          Text(
                            currentDay.celebration.name,
                            style: textScaling.scaledBodyLarge(context),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // Individual Reading Plan Cards (NEW APPROACH)
            _buildReadingPlanCards(context, ref, themeColor),

            // Welcome Header
            Text(
              'Choose your Bible reading experience',
              style: textScaling.scaledHeadlineSmall(context).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Navigation Options
            _buildNavigationGrid(context, ref, themeColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadingPlanCards(BuildContext context, WidgetRef ref, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    final activePlans = ref.watch(activeReadingPlansProvider);
    final hasReadToday = ref.watch(hasReadTodayProvider);
    
    if (activePlans.isEmpty) {
      // Show empty state encouraging users to create reading plans
      return Column(
        children: [
          _buildCreateFirstPlanCard(context, ref, themeColor),
          const SizedBox(height: 24),
        ],
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with reading status
        Row(
          children: [
            Icon(
              hasReadToday ? Icons.check_circle : Icons.auto_stories,
              color: hasReadToday 
                ? Colors.green
                : (themeColor ?? Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasReadToday 
                  ? 'Reading Progress Today ✅' 
                  : 'Your Reading Plans',
                style: textScaling.scaledTitleMedium(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: hasReadToday 
                    ? Colors.green.shade700
                    : (themeColor?.withValues(alpha: 0.8) ?? 
                       Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: hasReadToday 
                  ? Colors.green.withValues(alpha: 0.1)
                  : (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                hasReadToday ? 'Completed!' : '${activePlans.length} plan${activePlans.length != 1 ? 's' : ''}',
                style: textScaling.scaledLabelSmall(context).copyWith(
                  color: hasReadToday 
                    ? Colors.green.shade700
                    : (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.8),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Individual plan cards
        ...activePlans.map((plan) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildIndividualPlanCard(context, ref, plan, themeColor, hasReadToday),
        )),
        
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildIndividualPlanCard(BuildContext context, WidgetRef ref, ReadingPlan plan, Color? themeColor, bool hasReadToday) {
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
              // Plan header
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: textScaling.scaledTitleMedium(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: themeColor?.withValues(alpha: 0.9) ?? 
                             Theme.of(context).colorScheme.primary,
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
              
              const SizedBox(height: 12),
              
              // Next chapter highlight
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
                child: Row(
                  children: [
                    Icon(
                      Icons.menu_book,
                      color: themeColor ?? Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Next to read:',
                            style: textScaling.scaledBodySmall(context).copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                          Text(
                            plan.nextChapterText,
                            style: textScaling.scaledTitleMedium(context).copyWith(
                              fontWeight: FontWeight.bold,
                              color: themeColor ?? Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
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
              
              const SizedBox(height: 12),
              
              // Continue reading button
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Go directly to this plan's next chapter
                    context.push('/chapter/${Uri.encodeComponent(plan.progress.currentBook)}/${plan.progress.currentChapter}');
                  },
                  icon: Icon(
                    Icons.play_arrow,
                    size: 18,
                  ),
                  label: Text(
                    'Continue Reading',
                    style: textScaling.scaledBodyMedium(context).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor ?? Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateFirstPlanCard(BuildContext context, WidgetRef ref, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/reading-plan'),
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
                  size: textScaling.scaleFactor * 48,
                  color: themeColor?.withValues(alpha: 0.7) ?? 
                         Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 16),
                Text(
                  'Create Your First Reading Plan',
                  style: textScaling.scaledTitleLarge(context).copyWith(
                    fontWeight: FontWeight.bold,
                    color: themeColor?.withValues(alpha: 0.8) ?? 
                           Theme.of(context).colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Set up a reading plan to track your progress through the Bible. Read at your own pace!',
                  style: textScaling.scaledBodyLarge(context).copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => context.push('/reading-plan'),
                  icon: const Icon(Icons.add),
                  label: Text(
                    'Create Reading Plan',
                    style: textScaling.scaledBodyMedium(context).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor ?? Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationGrid(BuildContext context, WidgetRef ref, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Column(
      children: [
        // Row 1: Bible Lookup & Reading Plans
        Row(
          children: [
            Expanded(
              child: _buildNavigationCard(
                context: context,
                textScaling: textScaling,
                themeColor: themeColor,
                title: 'Bible Lookup',
                subtitle: 'Read any chapter',
                icon: Icons.menu_book,
                onTap: () => context.push('/bible-lookup'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildNavigationCard(
                context: context,
                textScaling: textScaling,
                themeColor: themeColor,
                title: 'Reading Plans',
                subtitle: 'Manage your plans',
                icon: Icons.calendar_today,
                onTap: () => context.push('/reading-plan'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Row 2: Continue Reading & Bible Search
        Row(
          children: [
            Expanded(
              child: _buildNavigationCard(
                context: context,
                textScaling: textScaling,
                themeColor: themeColor,
                title: 'Continue Reading',
                subtitle: 'Pick up where you left off',
                icon: Icons.play_circle_filled,
                onTap: () => context.push('/continue-reading'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildNavigationCard(
                context: context,
                textScaling: textScaling,
                themeColor: themeColor,
                title: 'Search Bible',
                subtitle: 'Find verses & topics',
                icon: Icons.search,
                onTap: () => context.push('/bible-search'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavigationCard({
    required BuildContext context,
    required TextScaling textScaling,
    required Color? themeColor,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: themeColor != null ? Border.all(
              color: themeColor.withValues(alpha: 0.3),
              width: 2,
            ) : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: textScaling.scaleFactor * 28,
                  color: themeColor ?? Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: Text(
                    title,
                    style: textScaling.scaledTitleSmall(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: themeColor?.withValues(alpha: 0.8) ?? 
                             Theme.of(context).colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    subtitle,
                    style: textScaling.scaledBodySmall(context).copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
