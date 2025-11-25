import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';

class ThemePreviewScreen extends ConsumerWidget {
  const ThemePreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the shared liturgical calendar provider
    final currentLiturgicalColorString = ref.watch(
      currentLiturgicalColorProvider,
    );
    final liturgicalColor = currentLiturgicalColorString != null
        ? LiturgicalColor.fromString(currentLiturgicalColorString)
        : null;
    final liturgicalSeason = ref.watch(currentLiturgicalSeasonProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Current liturgical info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Liturgical Season',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    liturgicalSeason ?? 'Ordinary Time',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Color: ${_getColorName(liturgicalColor)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ═══════════════════════════════════════
          // APPEARANCE SECTION (using shared UI)
          // ═══════════════════════════════════════
          const SettingsSectionHeader(title: 'Appearance'),

          // Theme mode selection (Light/Dark/System)
          const ThemeModeSelector(),

          // Color intensity selection (Vibrant/Muted)
          const ColorIntensitySelector(),

          // Liturgical color preview
          const LiturgicalColorPreview(),

          const Divider(),

          // ═══════════════════════════════════════
          // ACCESSIBILITY SECTION
          // ═══════════════════════════════════════
          const AccessibilitySettings(
            fontPreviewText:
                'Sample novena prayer text: "O Saint Jude, glorious apostle..."',
            showFontSize: true,
          ),

          const SizedBox(height: 24),

          // Preview section
          const SettingsSectionHeader(title: 'Preview'),
          const SizedBox(height: 16),

          // Sample UI elements
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sample Novena Card',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This card uses the current liturgical color as the accent color. Colors automatically change with the liturgical calendar and respect your vibrant/muted preference.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Begin Novena'),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('Learn More'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getColorName(LiturgicalColor? color) {
    if (color == null) return 'Default (Purple)';

    switch (color) {
      case LiturgicalColor.green:
        return 'Green (Ordinary Time)';
      case LiturgicalColor.purple:
        return 'Purple (Advent/Lent)';
      case LiturgicalColor.rose:
        return 'Rose (Gaudete/Laetare)';
      case LiturgicalColor.white:
        return 'White (Christmas/Easter)';
      case LiturgicalColor.red:
        return 'Red (Pentecost/Martyrs)';
      case LiturgicalColor.gold:
        return 'Gold (High Feasts)';
    }
  }
}
