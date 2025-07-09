import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/examination_provider.dart';
import '../providers/examination_session_provider.dart';
import '../../../utils/logger.dart';

class ExaminationIntroScreen extends ConsumerWidget {
  final String examinationId;

  const ExaminationIntroScreen({
    required this.examinationId, super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examinationAsync = ref.watch(examinationByIdProvider(examinationId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prepare for Examination'),
      ),
      body: examinationAsync.when(
        data: (examination) {
          if (examination == null) {
            return const Center(child: Text('Examination not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  examination.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Source: ${examination.source}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 24),

                // Introduction to the examination
                const Text(
                  'Before you begin:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Prayer guidance
                _buildSection(
                  context,
                  title: 'Prayer for Guidance',
                  content: 'Begin with a moment of prayer, asking the Holy Spirit to guide your reflection and bring to mind the ways you need to grow in love of God and neighbor.',
                  icon: Icons.favorite,
                ),

                _buildSection(
                  context,
                  title: 'Examination Process',
                  content: 'You will review different areas of your life based on ${examination.categories.length} categories. For each question, reflect honestly and mark any areas where you believe you have fallen short.',
                  icon: Icons.checklist,
                ),

                _buildSection(
                  context,
                  title: 'Be Thorough but Gentle',
                  content: "Examine your conscience thoroughly but avoid unhealthy scrupulosity. Focus on growth rather than shame, remembering God's mercy is infinite.",
                  icon: Icons.healing,
                ),

                const SizedBox(height: 32),

                Center(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      AppLogger.examination('Begin Examination button pressed for examinationId: $examinationId');
                      
                      // Before starting the examination
                      final beforeSession = ref.read(examinationSessionProvider);
                      AppLogger.examination("Before starting - Current session: ${beforeSession?.id ?? 'null'}");
                      
                      await ref.read(examinationSessionProvider.notifier)
                          .startExamination(examinationId);
                      
                      // After starting the examination  
                      final afterSession = ref.read(examinationSessionProvider);
                      AppLogger.examination("After starting - Current session: ${afterSession?.id ?? 'null'}");
                      
                      if (context.mounted) {
                        // Get the first category ID to use for navigation
                        final firstCategoryId = examination.categories.isNotEmpty 
                            ? examination.categories.first.id 
                            : '';
                            
                        AppLogger.examination('Context is mounted, attempting navigation with first category: $firstCategoryId');
                        
                        // Update the session with the first category
                        if (firstCategoryId.isNotEmpty) {
                          await ref.read(examinationSessionProvider.notifier)
                              .updatePosition(
                                firstCategoryId, 
                                examination.categories.first.items.first.id
                              );
                        }
                        
                        // Now navigate
                        if (context.mounted) {
                          context.go('/examination/$examinationId/category/$firstCategoryId');
                        }
                      } else {
                        AppLogger.warning('Context is NOT mounted after starting examination', 'EXAM');
                      }
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Begin Examination'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Opening prayer suggestion
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Suggested Opening Prayer',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Come Holy Spirit, enlighten my mind to see my sins, strengthen my heart to regret them sincerely, and give me the courage to confess them honestly. Merciful Father, guide me to true sorrow for having offended You, who are all good and deserving of all my love. Amen.',
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

  Widget _buildSection(
      BuildContext context, {
        required String title,
        required String content,
        required IconData icon,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
