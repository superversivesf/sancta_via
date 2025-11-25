import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/examination_session_model.dart';
import '../providers/examination_provider.dart';
import '../../../providers/text_scaling_provider.dart';

class CompletedExaminationsScreen extends ConsumerWidget {
  const CompletedExaminationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedExaminationsAsync = ref.watch(completedExaminationsProvider);
    final textScaling = ref.watch(textScaleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Completed Examinations'),
        actions: [
          // Optional: Add a button to delete all
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => _confirmDeleteAll(context, ref),
            tooltip: 'Delete All',
          ),
        ],
      ),
      body: completedExaminationsAsync.when(
        data: (completedExaminations) {
          if (completedExaminations.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No completed examinations',
                      style: textScaling.scaledHeadlineSmall(context),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'When you complete an examination of conscience, it will appear here until you delete it after confession.',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: completedExaminations.length,
            itemBuilder: (context, index) {
              final session = completedExaminations[index];
              return _buildCompletedExaminationCard(context, ref, session);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Error loading completed examinations: $error')),
      ),
    );
  }

  Widget _buildCompletedExaminationCard(
    BuildContext context,
    WidgetRef ref,
    ExaminationSession session,
  ) {
    final examinationAsync = ref.watch(
      examinationByIdProvider(session.examinationId),
    );
    final dateFormat = DateFormat('MMM d, yyyy h:mm a');
    final formattedDate = dateFormat.format(session.createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        // Make the entire ListTile tappable
        onTap: () {
          context.push('/completed/${session.id}');
        },
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(Icons.quiz, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(
          examinationAsync.value?.title ?? 'Examination',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Completed on $formattedDate'),
            const SizedBox(height: 4),
            Text(
              '${session.getMarkedItemIds().length} items marked for confession',
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _confirmDelete(context, ref, session.id),
          tooltip: 'Delete',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String sessionId,
  ) async {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Examination?'),
        content: const Text(
          'Are you sure you want to delete this completed examination?',
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
                  .deleteSession(sessionId);

              // Refresh the list
              ref.invalidate(completedExaminationsProvider);

              // Show confirmation
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Examination deleted')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Examinations?'),
        content: const Text(
          'Are you sure you want to delete all completed examinations? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              // Delete all sessions
              await ref.read(examinationRepositoryProvider).deleteAllSessions();

              // Refresh the list
              ref.invalidate(completedExaminationsProvider);

              // Show confirmation
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All examinations deleted')),
                );
              }
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }
}
