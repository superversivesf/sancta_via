import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import '../../features/examination/providers/examination_provider.dart';
import '../../features/examination/providers/examination_session_provider.dart';
import '../../providers/text_scaling_provider.dart';
import '../../config/constants.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liturgicalData = ref.watch(currentLiturgicalDayProvider);
    final activeSession = ref.watch(examinationSessionProvider);
    final defaultExamination = ref.watch(defaultExaminationProvider);
    final textScaling = ref.watch(textScaleProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: liturgicalData != null ? SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Liturgical Calendar Integration
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Today\'s Liturgical Season',
                          style: textScaling.scaledTitleMedium(context).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      liturgicalData.season,
                      style: textScaling.scaledHeadlineSmall(context).copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    if (liturgicalData.celebration.name.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        liturgicalData.celebration.name,
                        style: textScaling.scaledBodyLarge(context),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Active Session Section
            if (activeSession != null) ...[
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.play_circle_filled,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Active Examination',
                            style: textScaling.scaledTitleMedium(context).copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You have an examination in progress',
                        style: textScaling.scaledBodyMedium(context),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Continue'),
                            onPressed: () {
                              context.go('/examinations');
                            },
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.close),
                            label: const Text('Cancel'),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Cancel Examination?'),
                                  content: const Text('This will discard your current progress.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Keep'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Cancel'),
                                    ),
                                  ],
                                ),
                              );
                              
                              if (confirm == true) {
                                await ref.read(examinationSessionProvider.notifier)
                                    .cancelExamination();
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Quick Actions
            Text(
              'Quick Actions',
              style: textScaling.scaledHeadlineSmall(context).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Default examination quick start (if set)
            if (defaultExamination != null && activeSession == null) ...[
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    child: Icon(
                      Icons.star,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  title: Text('Start ${defaultExamination.title}'),
                  subtitle: const Text('Your default examination'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    context.go('/examination/${defaultExamination.id}');
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            // Browse all examinations
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.list,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: const Text('Browse Examinations'),
                subtitle: const Text('View all available examinations of conscience'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  context.go('/examinations');
                },
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Completed examinations
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                  child: Icon(
                    Icons.history,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
                title: const Text('Completed Examinations'),
                subtitle: const Text('View examinations ready for confession'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  context.go('/completed-examinations');
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Information Section
            Text(
              'About Examination of Conscience',
              style: textScaling.scaledHeadlineSmall(context).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preparation for Confession',
                      style: textScaling.scaledTitleMedium(context).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'An examination of conscience is a prayerful reflection on our sins and failings, '
                      'helping us to prepare well for the Sacrament of Confession. Through honest '
                      'self-examination, we open our hearts to God\'s mercy and grace.',
                      style: textScaling.scaledBodyMedium(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ) : const Center(child: CircularProgressIndicator()),
    );
  }
}
