import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/achievement.dart';
import '../../providers/achievement_providers.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievementsByCategory = ref.watch(achievementsByCategoryProvider);
    final earnedAsync = ref.watch(earnedAchievementsProvider);
    final totalPointsAsync = ref.watch(totalAchievementPointsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        actions: [
          // Total points badge
          totalPointsAsync.when(
            data: (points) => Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$points pts',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (error, stack) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: earnedAsync.when(
        data: (earnedList) {
          final earnedIds = earnedList.map((e) => e.achievementId).toSet();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(earnedAchievementsProvider);
              ref.invalidate(totalAchievementPointsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: achievementsByCategory.length,
              itemBuilder: (context, index) {
                final category = achievementsByCategory.keys.elementAt(index);
                final achievements = achievementsByCategory[category]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Header
                    CategoryHeader(category: category),
                    const SizedBox(height: 12),

                    // Achievements in this category
                    ...achievements.map((achievement) {
                      final isEarned = earnedIds.contains(achievement.id);
                      return AchievementCard(
                        achievement: achievement,
                        isEarned: isEarned,
                      );
                    }),

                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ErrorView(error: error),
      ),
    );
  }
}

class CategoryHeader extends StatelessWidget {
  final String category;

  const CategoryHeader({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          _getCategoryIcon(category),
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          category,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'First Time':
        return Icons.emoji_events;
      case 'Duration':
        return Icons.timer;
      case 'Streak':
        return Icons.local_fire_department;
      case 'Milestone':
        return Icons.star;
      case 'Special':
        return Icons.cake;
      default:
        return Icons.emoji_events;
    }
  }
}

class AchievementCard extends ConsumerWidget {
  final Achievement achievement;
  final bool isEarned;

  const AchievementCard({
    super.key,
    required this.achievement,
    required this.isEarned,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(achievementProgressProvider(achievement.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isEarned ? 4 : 1,
      color: isEarned
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Badge/Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isEarned
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isEarned
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  achievement.icon,
                  style: TextStyle(
                    fontSize: 28,
                    color: isEarned ? null : Colors.grey[600],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Achievement Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          achievement.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isEarned
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                        ),
                      ),
                      if (isEarned)
                        Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    achievement.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Progress bar (if not earned)
                  if (!isEarned)
                    progressAsync.when(
                      data: (progress) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 6,
                                    borderRadius: BorderRadius.circular(3),
                                    backgroundColor: Colors.grey[300],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${(progress * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                      loading: () => const SizedBox(
                        height: 6,
                        child: LinearProgressIndicator(),
                      ),
                      error: (error, stack) => const SizedBox.shrink(),
                    ),

                  // Points badge
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.star,
                        size: 14,
                        color: Colors.amber[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${achievement.points} pts',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final Object error;

  const ErrorView({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error Loading Achievements',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}
