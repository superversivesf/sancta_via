import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/logger.dart';
import '../models/confession_item_model.dart';
import '../providers/examination_provider.dart';
import '../providers/examination_session_provider.dart';
import '../../../providers/text_scaling_provider.dart';

class ExaminationSummaryScreen extends ConsumerWidget {
  final String examinationId;
  
  const ExaminationSummaryScreen({
    required this.examinationId, super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AppLogger.examination('Building ExaminationSummaryScreen');
    final sessionState = ref.watch(examinationSessionProvider);
    final textScaling = ref.watch(textScaleProvider);

    if (sessionState == null) {
      AppLogger.examination('Session state is null in summary screen');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppLogger.examination('Navigating back to first route due to null session');
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    AppLogger.examination('Session ID: ${sessionState.id}, Examination ID: ${sessionState.examinationId}');
    AppLogger.examination('Response count: ${sessionState.itemResponses.length}, Notes count: ${sessionState.notes.length}');

    final examinationAsync = ref.watch(
      examinationByIdProvider(sessionState.examinationId),
    );
    final confessionItems = ref.watch(confessionItemsProvider);

    AppLogger.examination('Confession items count: ${confessionItems.length}');

    return Scaffold(
      appBar: AppBar(title: const Text('Summary for Confession')),
      body: examinationAsync.when(
        data: (examination) {
          if (examination == null) {
            return const Center(child: Text('Examination not found'));
          }

          if (confessionItems.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No items marked for confession',
                      style: textScaling.scaledHeadlineSmall(context),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'You did not mark any items for confession. You may return to the examination to continue your reflection.',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Return to Examination'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Text(
                        'Items to Confess',
                        style: textScaling.scaledHeadlineSmall(context).copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Below is a list of items you marked during your examination of conscience. You may want to take a screenshot or write these down before confession.',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 24),

                      // List of items to confess
                      ...confessionItems.map(
                            (item) => _buildConfessionItem(context, item),
                      ),

                      const SizedBox(height: 32),

                      // Act of Contrition
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Act of Contrition',
                                style: textScaling.scaledTitleMedium(context).copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'O my God, I am heartily sorry for having offended Thee, and I detest all my sins because of Thy just punishments, but most of all because they offend Thee, my God, who art all good and deserving of all my love. I firmly resolve, with the help of Thy grace, to sin no more and to avoid the near occasions of sin. Amen.',
                                style: TextStyle(fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom action buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Continue examination button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Continue Examination'),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Complete button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showCompletionDialog(context, ref),
                        icon: const Icon(Icons.check),
                        label: const Text('Complete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Error loading examination: $error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );
  }

  Widget _buildConfessionItem(BuildContext context, ConfessionItem item) {
    return Consumer(
      builder: (context, ref, child) {
        final textScaling = ref.watch(textScaleProvider);
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.getDisplayText(),
                      style: textScaling.scaledBodyLarge(context).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (item.note != null && item.note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.note!,
                        style: textScaling.scaledBodySmall(context).copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCompletionDialog(BuildContext context, WidgetRef ref) async {
    AppLogger.examination('Showing completion dialog');

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button
      builder: (dialogContext) => AlertDialog(
        title: const Text('Complete Examination?'),
        content: const Text(
          'Have you prepared sufficiently for confession? Once completed, these items will be saved securely until you delete them after confession.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              AppLogger.examination('Completion dialog - Cancel pressed');
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              AppLogger.examination('Completion dialog - Complete pressed');

              // Close dialog first
              Navigator.of(dialogContext).pop();

              // Show success message
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Examination completed. May God bless your confession.'),
                    duration: Duration(seconds: 3),
                  ),
                );
              }

              // Complete the session
              await ref.read(examinationSessionProvider.notifier).completeExamination();

              // Navigate back to home - pop multiple times to get back to main screen
              if (context.mounted) {
                AppLogger.examination('Using multiple pops to return home');
                Navigator.of(context).pop(); // Pop summary screen
                Navigator.of(context).pop(); // Pop category screen  
                Navigator.of(context).pop(); // Pop intro screen
              }
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }
}
