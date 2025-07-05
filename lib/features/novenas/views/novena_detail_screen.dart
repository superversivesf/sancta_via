import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/novena_providers.dart';
import '../../../config/route_names.dart';
import '../providers/novena_state_provider.dart';

class NovenaDetailScreen extends ConsumerWidget {
  final String novenaId;

  const NovenaDetailScreen({
    super.key,
    required this.novenaId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final novenaAsync = ref.watch(novenaByIdProvider(novenaId));
    final hasActiveNovena = ref.watch(hasActiveNovenaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novena Details'),
      ),
      body: novenaAsync.when(
        data: (novena) {
          if (novena == null) {
            return const Center(child: Text('Novena not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section
                Text(
                  novena.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  novena.saint,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Feast Day: ${novena.feastDay}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 24),

                // Before you begin section
                const Text(
                  'Before you begin:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Information sections
                _buildSection(
                  context,
                  title: 'About this Novena',
                  content: novena.description,
                  icon: Icons.info_outline,
                ),

                if (novena.backgroundInfo != null)
                  _buildSection(
                    context,
                    title: 'Background',
                    content: novena.backgroundInfo!,
                    icon: Icons.history_edu,
                  ),

                _buildSection(
                  context,
                  title: 'What to Expect',
                  content: 'This novena consists of 9 days of prayer and reflection. Each day includes prayers, reflections, and scripture readings to deepen your devotion and strengthen your intentions.',
                  icon: Icons.schedule,
                ),

                _buildSection(
                  context,
                  title: 'Your Intention',
                  content: novena.intention,
                  icon: Icons.favorite,
                ),

                _buildSection(
                  context,
                  title: 'Instructions',
                  content: novena.instructions,
                  icon: Icons.checklist,
                ),

                const SizedBox(height: 32),

                // Action button
                if (!hasActiveNovena) ...[
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.pushNamed(
                          RouteNames.novenaConfiguration,
                          pathParameters: {'novenaId': novenaId},
                        );
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('Begin Configuration'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.block,
                          size: 48,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'You have an active novena in progress',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Complete or cancel your current novena before starting a new one',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            context.pushNamed(RouteNames.activeNovena);
                          },
                          child: const Text('View Active Novena'),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Suggested opening prayer
                if (novena.notes != null) ...[
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Additional Notes',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            novena.notes!,
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Error loading novena: $error',
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
