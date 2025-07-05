import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/examination_model.dart';
import '../models/user_preferences_model.dart';
import '../providers/examination_provider.dart';

class ExaminationListScreen extends ConsumerStatefulWidget {
  const ExaminationListScreen({super.key});

  @override
  ConsumerState<ExaminationListScreen> createState() => _ExaminationListScreenState();
}

class _ExaminationListScreenState extends ConsumerState<ExaminationListScreen> {
  bool _isProcessingFavorite = false;
  bool _isProcessingDefault = false;

  @override
  Widget build(BuildContext context) {
    final examinationsAsync = ref.watch(examinationsProvider);
    final preferences = ref.watch(examinationPreferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Examination of Conscience'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to examination preferences
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Preferences - Coming Soon')),
              );
            },
            tooltip: 'Preferences',
          ),
        ],
      ),
      body: examinationsAsync.when(
        data: (examinations) {
          // Sort examinations: default first, then favorites, then others
          final sortedExaminations = _sortExaminations(examinations, preferences);

          return ListView(
            children: [
              // Default examination section if one is set
              if (preferences.defaultExaminationId != null) ...[
                _buildSectionHeader(context, 'Default Examination'),
                _buildExaminationCard(
                  context,
                  ref,
                  sortedExaminations.firstWhere(
                        (exam) => exam.id == preferences.defaultExaminationId,
                  ),
                  isDefault: true,
                ),
              ],

              // Favorites section if any exist
              if (preferences.favoriteExaminationIds.isNotEmpty) ...[
                _buildSectionHeader(context, 'Favorites'),
                ...sortedExaminations
                    .where((exam) =>
                preferences.favoriteExaminationIds.contains(exam.id) &&
                    exam.id != preferences.defaultExaminationId)
                    .map((exam) => _buildExaminationCard(context, ref, exam, isFavorite: true)),
              ],

              // All examinations section
              _buildSectionHeader(context, 'All Examinations'),
              ...sortedExaminations
                  .where((exam) =>
              // Exclude favorites and default examination (they're shown in their own sections)
              !preferences.favoriteExaminationIds.contains(exam.id) &&
                  exam.id != preferences.defaultExaminationId)
                  .map((exam) => _buildExaminationCard(context, ref, exam)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(
            'Error loading examinations: $error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );
  }

  // Helper method to sort examinations
  List<ExaminationModel> _sortExaminations(
      List<ExaminationModel> examinations,
      ExaminationPreferences preferences
      ) {
    return [...examinations]..sort((a, b) {
      // Default examination comes first
      if (a.id == preferences.defaultExaminationId) return -1;
      if (b.id == preferences.defaultExaminationId) return 1;

      // Then favorites
      final aIsFavorite = preferences.favoriteExaminationIds.contains(a.id);
      final bIsFavorite = preferences.favoriteExaminationIds.contains(b.id);

      if (aIsFavorite && !bIsFavorite) return -1;
      if (!aIsFavorite && bIsFavorite) return 1;

      // Then alphabetically
      return a.title.compareTo(b.title);
    });
  }

  // Helper method to build section headers
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Helper method to build an examination card with favorite/default functionality
  Widget _buildExaminationCard(
      BuildContext context,
      WidgetRef ref,
      ExaminationModel examination, {
        bool isFavorite = false,
        bool isDefault = false,
      }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/examination/${examination.id}');
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      examination.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  // Favorite toggle button
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : null,
                    ),
                    onPressed: _isProcessingFavorite ? null : () => _handleFavoriteToggle(examination.id),
                    tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                  ),
                  // Default toggle menu
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: isDefault ? Theme.of(context).colorScheme.primary : null,
                    ),
                    onSelected: _isProcessingDefault ? null : (value) => _handleMenuSelection(value, examination.id, isDefault),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'default',
                        child: Row(
                          children: [
                            Icon(
                              isDefault ? Icons.star : Icons.star_border,
                              color: isDefault ? Theme.of(context).colorScheme.primary : null,
                            ),
                            const SizedBox(width: 8),
                            Text(isDefault ? 'Remove as default' : 'Set as default'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                examination.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, // Horizontal spacing between chips
                runSpacing: 8, // Vertical spacing between rows if chips wrap
                children: [
                  Chip(
                    label: Text(examination.targetAudience),
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  Chip(
                    label: Text('${examination.totalItems} questions'),
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  ),
                  if (isDefault)
                    Chip(
                      label: const Text('Default'),
                      backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                      avatar: const Icon(Icons.star, size: 16),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to handle favorite toggle with debouncing
  Future<void> _handleFavoriteToggle(String examinationId) async {
    if (_isProcessingFavorite) return;

    setState(() {
      _isProcessingFavorite = true;
    });

    try {
      await ref.read(examinationPreferencesProvider.notifier)
          .toggleFavorite(examinationId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update favorite: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingFavorite = false;
        });
      }
    }
  }

  // Helper method to handle menu selection with debouncing
  Future<void> _handleMenuSelection(String value, String examinationId, bool isDefault) async {
    if (_isProcessingDefault) return;

    if (value == 'default') {
      setState(() {
        _isProcessingDefault = true;
      });

      try {
        await ref.read(examinationPreferencesProvider.notifier)
            .setDefaultExamination(isDefault ? null : examinationId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update default examination: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isProcessingDefault = false;
          });
        }
      }
    }
  }
}
