import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/examination_provider.dart';
import '../providers/examination_session_provider.dart';
import '../../../providers/text_scaling_provider.dart';
import '../../../utils/logger.dart';

class ExaminationIntroScreen extends ConsumerWidget {
  final String examinationId;

  const ExaminationIntroScreen({
    required this.examinationId, super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examinationAsync = ref.watch(examinationByIdProvider(examinationId));
    final textScaling = ref.watch(textScaleProvider);

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
                  style: textScaling.scaledHeadlineMedium(context).copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Source: ${examination.source}',
                  style: textScaling.scaledBodyMedium(context).copyWith(
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
                  child: Consumer(
                    builder: (context, ref, child) {
                      final currentSession = ref.watch(examinationSessionProvider);
                      final isResumable = currentSession?.examinationId == examinationId;
                      
                      return ElevatedButton.icon(
                        onPressed: () async {
                          AppLogger.examination('Begin/Resume Examination button pressed for examinationId: $examinationId');
                          
                          if (isResumable && currentSession != null) {
                            // Resume existing session
                            AppLogger.examination('Resuming existing session: ${currentSession.id}');
                            
                            String targetCategoryId;
                            String targetItemId;
                            
                            if (currentSession.currentCategoryId != null && 
                                currentSession.currentItemId != null) {
                              // Resume from saved position
                              targetCategoryId = currentSession.currentCategoryId!;
                              targetItemId = currentSession.currentItemId!;
                              AppLogger.examination('Resuming from saved position - Category: $targetCategoryId, Item: $targetItemId');
                            } else {
                              // No saved position, start from beginning
                              targetCategoryId = examination.categories.first.id;
                              targetItemId = examination.categories.first.items.first.id;
                              AppLogger.examination('No saved position, starting from beginning');
                              
                              // Update session with starting position
                              await ref.read(examinationSessionProvider.notifier)
                                  .updatePosition(targetCategoryId, targetItemId);
                            }
                            
                            if (context.mounted) {
                              context.push('/examination/$examinationId/category/$targetCategoryId');
                            }
                          } else {
                            // Start new session
                            AppLogger.examination('Starting new examination session');
                            
                            await ref.read(examinationSessionProvider.notifier)
                                .startExamination(examinationId);
                            
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
                                context.push('/examination/$examinationId/category/$firstCategoryId');
                              }
                            } else {
                              AppLogger.warning('Context is NOT mounted after starting examination', 'EXAM');
                            }
                          }
                        },
                        icon: Icon(isResumable ? Icons.replay : Icons.play_arrow),
                        label: Text(isResumable ? 'Resume Examination' : 'Begin Examination'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      );
                    },
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
                          style: textScaling.scaledTitleMedium(context).copyWith(
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
    return Consumer(
      builder: (context, ref, child) {
        final textScaling = ref.watch(textScaleProvider);
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
                      style: textScaling.scaledTitleMedium(context).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      content,
                      style: textScaling.scaledBodyMedium(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
