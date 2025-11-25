import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/novena.dart';
import '../providers/novena_providers.dart';
import '../../../config/route_names.dart';
import '../providers/novena_state_provider.dart';

/// Novena List Screen following examination styling patterns
class NovenaListScreen extends ConsumerWidget {
  const NovenaListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final novenaListAsync = ref.watch(novenaMetadataListProvider);
    final hasActiveNovena = ref.watch(hasActiveNovenaProvider);

    // Redirect to active novena dashboard if one exists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasActiveNovena && context.mounted) {
        context.goNamed(RouteNames.activeNovena);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novenas'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            context.goNamed(RouteNames.home);
          },
          tooltip: 'Back to Home',
        ),
      ),
      body: novenaListAsync.when(
        data: (novenas) {
          if (novenas.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView(
            children: [
              // Info section about novenas
              if (!hasActiveNovena) ...[_buildInfoSection(context)],

              // Active novena banner if one exists
              if (hasActiveNovena) ...[_buildActiveNovenaBanner(context, ref)],

              // All novenas section
              _buildSectionHeader(context, 'Available Novenas'),
              ...novenas.map(
                (novena) => _buildNovenaCard(
                  context,
                  ref,
                  novena,
                  hasActiveNovena: hasActiveNovena,
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(context, ref, error),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'About Novenas',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'A novena is a nine-day period of prayer and reflection focused on a particular saint or intention. Choose a novena below to begin your spiritual journey.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveNovenaBanner(BuildContext context, WidgetRef ref) {
    final activeNovena = ref.watch(novenaStateProvider);
    if (activeNovena == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.play_circle_filled,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(width: 8),
              Text(
                'Active Novena',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.tertiary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Day ${activeNovena.spiritualDay} of 9',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onTertiaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: activeNovena.progressPercentage,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.outline.withAlpha(77),
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.tertiary,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              context.pushNamed(RouteNames.activeNovena);
            },
            child: const Text('Continue Novena'),
          ),
        ],
      ),
    );
  }

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

  Widget _buildNovenaCard(
    BuildContext context,
    WidgetRef ref,
    NovenaMetadata novena, {
    required bool hasActiveNovena,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: hasActiveNovena
            ? null
            : () {
                context.pushNamed(
                  RouteNames.novenaDetail,
                  pathParameters: {'novenaId': novena.id},
                );
              },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          novena.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          novena.saint,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                novena.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(novena.intentionCategory),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.secondaryContainer,
                  ),
                  Chip(
                    label: Text('${novena.durationMinutes} min'),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                  ),
                  Chip(
                    label: Text(novena.difficulty),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.tertiaryContainer,
                  ),
                ],
              ),
              if (hasActiveNovena) ...[
                const SizedBox(height: 12),
                Text(
                  'Complete your current novena before starting a new one',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
          ),
          const SizedBox(height: 16),
          Text(
            'No novenas available',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64),
          const SizedBox(height: 16),
          Text(
            'Failed to load novenas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ref.invalidate(novenaMetadataListProvider);
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
