import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/route_names.dart';
import '../../novenas/providers/novena_state_provider.dart';
import '../../../providers/liturgical_calendar_provider.dart';
import '../../../widgets/feature_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeNovena = ref.watch(novenaStateProvider);
    final liturgicalSeason = ref.watch(liturgicalSeasonProvider);
    final liturgicalColor = ref.watch(activeLiturgicalColorProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novena Companion'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.pushNamed(RouteNames.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome section with liturgical info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome to your spiritual journey',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Deepen your faith through the power of novena prayers',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Liturgical info - compact layout
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getLiturgicalIcon(liturgicalColor),
                                    size: 14,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      liturgicalSeason,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Active novena section
              if (activeNovena != null) ...[
                Text('Your Active Novena', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                FeatureCard(
                  icon: Icons.auto_awesome,
                  title: 'Continue Your Journey',
                  subtitle: 'Day ${activeNovena.spiritualDay} of 9',
                  description: 'Tap to continue your current novena',
                  onTap: () => context.pushNamed(RouteNames.activeNovena),
                  trailing: const Icon(Icons.arrow_forward_ios),
                ),
                const SizedBox(height: 24),
              ],

              // Main features
              Text('Explore Novenas', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),

              FeatureCard(
                icon: Icons.favorite,
                title: 'Browse Novenas',
                subtitle: 'Find the perfect novena for your intention',
                description:
                    'Explore our collection of traditional Catholic novenas',
                onTap: () => context.pushNamed(RouteNames.novenas),
              ),

              if (activeNovena == null) ...[
                const SizedBox(height: 12),
                FeatureCard(
                  icon: Icons.play_circle_outline,
                  title: 'Start a Novena',
                  subtitle: 'Begin your 9-day spiritual journey',
                  description:
                      'Choose from novenas for various intentions and saints',
                  onTap: () => context.pushNamed(RouteNames.novenas),
                ),
              ],

              const SizedBox(height: 32),

              // Footer
              Center(
                child: Text(
                  'May your prayers be heard and answered',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getLiturgicalIcon(LiturgicalColor color) {
    switch (color) {
      case LiturgicalColor.green:
        return Icons.eco; // Nature/growth for Ordinary Time
      case LiturgicalColor.purple:
        return Icons.local_florist; // Preparation/reflection for Advent/Lent
      case LiturgicalColor.rose:
        return Icons.favorite; // Joy for Gaudete/Laetare
      case LiturgicalColor.white:
        return Icons.star; // Celebration for Christmas/Easter
      case LiturgicalColor.red:
        return Icons.whatshot; // Fire for Pentecost/martyrs
      case LiturgicalColor.gold:
        return Icons.diamond; // Precious for high feasts
    }
  }
}
