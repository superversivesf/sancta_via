import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/examination_response_status.dart';
import '../providers/examination_provider.dart';
import '../providers/examination_session_provider.dart';

class ExaminationQuestionsScreen extends ConsumerStatefulWidget {
  final String examinationId;
  final String categoryId;

  const ExaminationQuestionsScreen({
    required this.examinationId, required this.categoryId, super.key,
  });

  @override
  ConsumerState<ExaminationQuestionsScreen> createState() => _ExaminationQuestionsScreenState();
}

class _ExaminationQuestionsScreenState extends ConsumerState<ExaminationQuestionsScreen> {
  String? _currentItemId;
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCurrentItem();
    });
  }

  void _initCurrentItem() {
    final sessionState = ref.read(examinationSessionProvider);
    final examinationAsync = ref.read(examinationByIdProvider(sessionState!.examinationId));

    if (examinationAsync.value != null) {
      final examination = examinationAsync.value!;
      final category = examination.categories.firstWhere((c) => c.id == widget.categoryId);

      // If there's a saved position in this category, use it
      if (sessionState.currentCategoryId == category.id &&
          sessionState.currentItemId != null &&
          category.items.any((item) => item.id == sessionState.currentItemId)) {
        setState(() {
          _currentItemId = sessionState.currentItemId;
        });
      } else {
        // Otherwise start with the first item
        setState(() {
          _currentItemId = category.items.first.id;
        });
      }

      // Save the position
      ref.read(examinationSessionProvider.notifier).updatePosition(
          category.id,
          _currentItemId!
      );
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(examinationSessionProvider);

    if (sessionState == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final examinationAsync = ref.watch(examinationByIdProvider(sessionState.examinationId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Examination'),
        actions: [
          // Save & Exit button
          TextButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save & Exit'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: examinationAsync.when(
        data: (examination) {
          if (examination == null) {
            return const Center(child: Text('Examination not found'));
          }

          final category = examination.categories.firstWhere((c) => c.id == widget.categoryId);
          final items = category.items;

          if (_currentItemId == null || !items.any((item) => item.id == _currentItemId)) {
            return const Center(child: Text('Item not found'));
          }

          final currentItem = items.firstWhere((item) => item.id == _currentItemId);
          final currentIndex = items.indexWhere((item) => item.id == _currentItemId);
          final responseStatus = sessionState.itemResponses[currentItem.id] ??
              ExaminationResponseStatus.notReviewed;
          final note = sessionState.notes[currentItem.id] ?? '';

          // Set the note controller text if it's not already set
          if (_noteController.text != note) {
            _noteController.text = note;
          }

          return Column(
            children: [
              // Progress through this category
              LinearProgressIndicator(
                value: (currentIndex + 1) / items.length,
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category title
                      Text(
                        category.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Question number
                      Text(
                        'Question ${currentIndex + 1} of ${items.length}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Question text
                      Text(
                        currentItem.text,
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1.5,
                        ),
                      ),

                      // Optional clarification
                      if (currentItem.clarification != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  currentItem.clarification!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Response buttons
                      Row(
                        children: [
                          // Need to Confess button
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: Icon(
                                responseStatus == ExaminationResponseStatus.needConfess
                                    ? Icons.check_circle
                                    : Icons.add_circle_outline,
                              ),
                              label: const Text('Need to Confess'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: responseStatus == ExaminationResponseStatus.needConfess
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                                foregroundColor: responseStatus == ExaminationResponseStatus.needConfess
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : null,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () {
                                ref.read(examinationSessionProvider.notifier)
                                    .setResponseStatus(
                                    currentItem.id,
                                    ExaminationResponseStatus.needConfess
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          // All Good button
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: Icon(
                                responseStatus == ExaminationResponseStatus.noIssue
                                    ? Icons.check_circle
                                    : Icons.check_circle_outline,
                              ),
                              label: const Text('This is OK'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: responseStatus == ExaminationResponseStatus.noIssue
                                    ? Theme.of(context).colorScheme.secondaryContainer
                                    : null,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () {
                                ref.read(examinationSessionProvider.notifier)
                                    .setResponseStatus(
                                    currentItem.id,
                                    ExaminationResponseStatus.noIssue
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Add note (only appears when "Need to Confess" is selected)
                      if (responseStatus == ExaminationResponseStatus.needConfess) ...[
                        const Text(
                          'Add a note (optional):',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _noteController,
                          decoration: const InputDecoration(
                            hintText: 'E.g., frequency, circumstances, etc.',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          onChanged: (value) {
                            ref.read(examinationSessionProvider.notifier)
                                .updateNote(currentItem.id, value);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Navigation buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Previous button
                    if (currentIndex > 0)
                      ElevatedButton.icon(
                        onPressed: () {
                          final prevItem = items[currentIndex - 1];
                          setState(() {
                            _currentItemId = prevItem.id;
                          });

                          // Save position
                          ref.read(examinationSessionProvider.notifier)
                              .updatePosition(category.id, prevItem.id);
                        },
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Previous'),
                      )
                    else
                      const SizedBox(width: 100),

                    // Next button
                    ElevatedButton.icon(
                      onPressed: () {
                        if (currentIndex < items.length - 1) {
                          // Go to next question
                          final nextItem = items[currentIndex + 1];
                          setState(() {
                            _currentItemId = nextItem.id;
                          });

                          // Save position
                          ref.read(examinationSessionProvider.notifier)
                              .updatePosition(category.id, nextItem.id);
                        } else {
                          // Last question in category - show completion dialog
                          _showCategoryCompletionDialog(context, examination, category);
                        }
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(
                        currentIndex < items.length - 1 ? 'Next' : 'Complete Section',
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

  void _showCategoryCompletionDialog(BuildContext context, examination, category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Section Complete'),
        content: Text('You have completed "${category.title}". What would you like to do next?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to examination list
            },
            child: const Text('Finish for Now'),
          ),
          if (_hasNextCategory(examination, category))
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                final nextCategory = _getNextCategory(examination, category);
                if (nextCategory != null) {
                  context.go('/examination/${examination.id}/category/${nextCategory.id}');
                }
              },
              child: const Text('Continue to Next Section'),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              // Navigate to summary screen
              context.go('/examination/${examination.id}/summary');
            },
            child: const Text('View Summary'),
          ),
        ],
      ),
    );
  }

  bool _hasNextCategory(examination, currentCategory) {
    final currentIndex = examination.categories.indexWhere((c) => c.id == currentCategory.id);
    return currentIndex < examination.categories.length - 1;
  }

  dynamic _getNextCategory(examination, currentCategory) {
    final currentIndex = examination.categories.indexWhere((c) => c.id == currentCategory.id);
    if (currentIndex < examination.categories.length - 1) {
      return examination.categories[currentIndex + 1];
    }
    return null;
  }
}
