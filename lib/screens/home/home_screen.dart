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

            // Today's Reading Plans Summary
            _buildTodaysReadingSummary(context, ref, themeColor),
            const SizedBox(height: 24),

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

  Widget _buildQuickReadSection(BuildContext context, WidgetRef ref, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    final currentPosition = ref.watch(currentReadingPositionProvider);
    final todaysUnread = ref.watch(todaysUnreadPlansProvider);
    final activePlans = ref.watch(activeReadingPlansProvider);
    
    // Don't show if no active plans
    if (activePlans.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Determine what to show
    final hasUnreadToday = todaysUnread.isNotEmpty;
    final primaryReading = currentPosition;
    
    if (primaryReading == null) {
      return const SizedBox.shrink();
    }
    
    final buttonText = hasUnreadToday 
        ? 'Read Today: ${primaryReading.displayText}'
        : 'Continue Reading: ${primaryReading.displayText}';
    
    final subtitle = hasUnreadToday
        ? 'Today\'s reading from ${primaryReading.planName}'
        : 'Continue where you left off';
        
    final icon = hasUnreadToday ? Icons.today : Icons.auto_stories;
    
    return Card(
      elevation: hasUnreadToday ? 4 : 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: themeColor != null ? Border.all(
            color: themeColor.withValues(alpha: hasUnreadToday ? 0.6 : 0.3),
            width: hasUnreadToday ? 3 : 2,
          ) : null,
          gradient: hasUnreadToday && themeColor != null ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              themeColor.withValues(alpha: 0.1),
              themeColor.withValues(alpha: 0.05),
            ],
          ) : null,
        ),
        child: InkWell(
          onTap: () {
            // Navigate directly to the current reading position
            context.push('/chapter/${Uri.encodeComponent(primaryReading.book)}/${primaryReading.startChapter}');
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: themeColor ?? Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        buttonText,
                        style: textScaling.scaledTitleMedium(context).copyWith(
                          fontWeight: FontWeight.bold,
                          color: themeColor?.withValues(alpha: 0.9) ?? 
                                 Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: textScaling.scaledBodyMedium(context).copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      if (hasUnreadToday) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Tap to start reading',
                            style: textScaling.scaledLabelSmall(context).copyWith(
                              color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward_ios,
                  color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.6),
                  size: 20,
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
                subtitle: 'Structured reading',
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

  Widget _buildTodaysReadingSummary(BuildContext context, WidgetRef ref, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    final todaysPlans = ref.watch(todaysReadingPlansProvider);
    final todaysUnreadPlans = ref.watch(todaysUnreadPlansProvider);
    
    if (todaysPlans.isEmpty) {
      return const SizedBox.shrink(); // Don't show anything if no plans for today
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
                    Icons.today,
                    color: themeColor ?? Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Today\'s Reading Plans',
                      style: textScaling.scaledTitleMedium(context).copyWith(
                        fontWeight: FontWeight.bold,
                        color: themeColor?.withValues(alpha: 0.8) ?? 
                               Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      todaysUnreadPlans.isEmpty ? 'All Complete!' : '${todaysUnreadPlans.length} to read',
                      style: textScaling.scaledLabelSmall(context).copyWith(
                        color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Quick summary of today's plans
              ...todaysPlans.take(3).map((plan) {
                final todaysReading = TodaysReading.fromPlan(plan);
                final isRead = plan.hasReadToday;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        isRead ? Icons.check_circle : Icons.circle_outlined,
                        size: 16,
                        color: isRead 
                          ? (themeColor ?? Theme.of(context).colorScheme.primary)
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${plan.name}: ${todaysReading.displayText}',
                          style: textScaling.scaledBodyMedium(context).copyWith(
                            color: isRead 
                              ? (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.8)
                              : null,
                            fontWeight: isRead ? FontWeight.w500 : null,
                          ),
                        ),
                      ),
                      if (isRead) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Done',
                            style: textScaling.scaledLabelSmall(context).copyWith(
                              color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.8),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              
              if (todaysPlans.length > 3) ...[
                Text(
                  '...and ${todaysPlans.length - 3} more plan${todaysPlans.length - 3 != 1 ? 's' : ''}',
                  style: textScaling.scaledBodySmall(context).copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Continue reading button
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (todaysUnreadPlans.isEmpty && todaysPlans.isNotEmpty) {
                      // All readings complete - jump to next chapter of first plan
                      final firstPlan = todaysPlans.first;
                      final nextReading = _getNextReading(firstPlan);
                      if (nextReading != null) {
                        _continueToNextChapter(context, ref, firstPlan.id, nextReading);
                      } else {
                        context.push('/continue-reading');
                      }
                    } else if (todaysUnreadPlans.isNotEmpty) {
                      // Go directly to the first unread plan's current chapter
                      final firstUnreadPlan = todaysUnreadPlans.first;
                      final currentReading = TodaysReading.fromPlan(firstUnreadPlan);
                      context.push('/chapter/${Uri.encodeComponent(currentReading.book)}/${currentReading.startChapter}');
                    } else {
                      // Fallback to continue reading screen
                      context.push('/continue-reading');
                    }
                  },
                  icon: Icon(
                    todaysUnreadPlans.isEmpty ? Icons.auto_stories : Icons.menu_book,
                    size: 18,
                  ),
                  label: Text(
                    todaysUnreadPlans.isEmpty 
                      ? 'Continue Reading${_getNextChapterText(todaysPlans)}' 
                      : 'Continue Reading',
                    style: textScaling.scaledBodyMedium(context).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor ?? Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
          height: 160, // Increased height to prevent text wrapping issues
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: themeColor != null ? Border.all(
              color: themeColor.withValues(alpha: 0.3),
              width: 2,
            ) : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12), // Reduced padding slightly
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // Added to prevent overflow
              children: [
                Icon(
                  icon,
                  size: textScaling.scaleFactor * 28, // Slightly smaller icon
                  color: themeColor ?? Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8), // Reduced spacing
                Flexible( // Made text flexible
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
                Flexible( // Made subtitle flexible
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

  /// Get the next reading after advancing progress for a plan
  TodaysReading? _getNextReading(ReadingPlan plan) {
    try {
      // Create a temporary updated progress to see what the next reading would be
      final currentProgress = plan.progress;
      var nextChapter = currentProgress.currentChapter + plan.chaptersPerDay;
      var nextBook = currentProgress.currentBook;
      var nextBookIndex = currentProgress.bookIndex;
      
      // Handle book boundaries (simplified version)
      final chapterCounts = {
        'Genesis': 50, 'Exodus': 40, 'Leviticus': 27, 'Numbers': 36, 'Deuteronomy': 34,
        'Matthew': 28, 'Mark': 16, 'Luke': 24, 'John': 21, 'Acts': 28,
        // Add more as needed - this is a simplified version
      };
      
      final currentBookChapters = chapterCounts[nextBook] ?? 30;
      if (nextChapter > currentBookChapters) {
        // Move to next book
        nextBookIndex++;
        if (nextBookIndex < currentProgress.books.length) {
          nextBook = currentProgress.books[nextBookIndex];
          nextChapter = 1;
        } else {
          // Plan completed
          return null;
        }
      }
      
      return TodaysReading(
        planId: plan.id,
        planName: plan.name,
        book: nextBook,
        startChapter: nextChapter,
        chaptersToRead: plan.chaptersPerDay,
        hasReadToday: plan.hasReadToday,
        collection: plan.collection,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get text showing the next chapter that will be read
  String _getNextChapterText(List<ReadingPlan> plans) {
    if (plans.isEmpty) return '';
    
    final firstPlan = plans.first;
    final nextReading = _getNextReading(firstPlan);
    if (nextReading == null) return '';
    
    return ' (${nextReading.displayText})';
  }

  /// Continue to next chapter without resetting daily status
  void _continueToNextChapter(BuildContext context, WidgetRef ref, String planId, TodaysReading nextReading) {
    // Advance the plan to the next chapter
    ref.read(readingPlanManagerProvider.notifier).advanceToNextChapter(planId);
    
    // Navigate directly to the next chapter
    context.push('/chapter/${Uri.encodeComponent(nextReading.book)}/${nextReading.startChapter}');
    
    // Show encouraging message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📖 Opening ${nextReading.displayText}. Visit the chapter to mark as complete!'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
