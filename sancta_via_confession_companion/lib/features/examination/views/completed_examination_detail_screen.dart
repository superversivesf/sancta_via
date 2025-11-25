import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/confession_item_model.dart';
import '../providers/examination_provider.dart';
import '../../../providers/text_scaling_provider.dart';

class CompletedExaminationDetailScreen extends ConsumerWidget {
  final String completedExaminationId;

  const CompletedExaminationDetailScreen({
    required this.completedExaminationId,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(
      completedSessionProvider(completedExaminationId),
    );
    final confessionItems = ref.watch(
      completedSessionItemsProvider(completedExaminationId),
    );
    final textScaling = ref.watch(textScaleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Confession Summary')),
      body: sessionAsync.when(
        data: (session) {
          if (session == null) {
            return const Center(child: Text('Session not found'));
          }

          final examinationAsync = ref.watch(
            examinationByIdProvider(session.examinationId),
          );

          return examinationAsync.when(
            data: (examination) {
              if (examination == null) {
                return const Center(child: Text('Examination not found'));
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
                            style: textScaling
                                .scaledHeadlineSmall(context)
                                .copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Examination: ${examination.title}',
                            style: textScaling
                                .scaledBodyLarge(context)
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Completed: ${_formatDate(session.createdAt)}',
                            style: textScaling
                                .scaledBodyMedium(context)
                                .copyWith(
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color,
                                ),
                          ),
                          const SizedBox(height: 24),

                          // Instructions
                          Card(
                            color: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Use this list during confession, then delete it afterwards to maintain your privacy.',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // List of items
                          if (confessionItems.isEmpty) ...[
                            Text(
                              'No items were marked for confession in this examination.',
                              style: textScaling.scaledBodyLarge(context),
                            ),
                          ] else ...[
                            ...confessionItems.map(
                              (item) => _buildConfessionItem(context, item),
                            ),
                          ],

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
                                    style: textScaling
                                        .scaledTitleMedium(context)
                                        .copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'O my God, I am heartily sorry for having offended Thee, and I detest all my sins because of Thy just punishments, but most of all because they offend Thee, my God, who art all good and deserving of all my love. I firmly resolve, with the help of Thy grace, to sin no more and to avoid the near occasions of sin. Amen.',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom action button
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
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _confirmDelete(context, ref),
                            icon: const Icon(Icons.delete),
                            label: const Text('Delete After Confession'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onError,
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
            error: (error, _) =>
                Center(child: Text('Error loading examination: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Error loading session: $error')),
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
                      style: textScaling
                          .scaledBodyLarge(context)
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (item.note != null && item.note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.note!,
                        style: textScaling
                            .scaledBodySmall(context)
                            .copyWith(
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color,
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

  String _formatDate(DateTime date) {
    final formatter = DateFormat('MMM d, yyyy h:mm a');
    return formatter.format(date);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Examination?'),
        content: const Text(
          'Have you completed your confession? This will delete the examination record.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              // Delete the session
              await ref
                  .read(examinationRepositoryProvider)
                  .deleteSession(completedExaminationId);

              // Refresh the provider
              ref.invalidate(completedExaminationsProvider);

              // Show confirmation and navigate back
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Examination deleted')),
                );
                Navigator.of(context).pop();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
