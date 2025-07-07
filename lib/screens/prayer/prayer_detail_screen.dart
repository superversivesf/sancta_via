import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import '../../models/prayer.dart';
import '../../models/prayer_preferences.dart';
import '../../providers/prayer_providers.dart';
import '../../providers/prayer_app_settings_provider.dart';
import '../../providers/text_scaling_provider.dart';
import '../../widgets/enhanced_prayer_text.dart';
import '../settings/settings_screen.dart';

class PrayerDetailScreen extends ConsumerWidget {
  final String prayerId;

  const PrayerDetailScreen({
    super.key,
    required this.prayerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayerAsync = ref.watch(prayerProvider(prayerId));
    final preferences = ref.watch(prayerPreferencesProvider);
    final isFavorite = preferences.favoritePrayerIds.contains(prayerId);
    final textScaling = ref.watch(textScaleProvider);
    final defaultLanguage = ref.watch(prayerDefaultLanguageProvider);
    // Get the currently selected translation
    final selectedTranslation = ref.watch(selectedTranslationProvider(prayerId)) ?? defaultLanguage;
    
    // Get liturgical color for theming
    final currentColor = ref.watch(currentLiturgicalColorProvider);
    final colorIntensity = ref.watch(colorIntensityProvider);
    final liturgicalColor = currentColor != null 
        ? LiturgicalColor.fromString(currentColor)
        : null;
    final themeColor = liturgicalColor?.toFlutterColor(colorIntensity);

    // Add to recent prayers when screen is built
    ref.listen(prayerProvider(prayerId), (previous, next) {
      if (next.hasValue && next.value != null) {
        ref.read(prayerAppSettingsProvider.notifier).addToRecent(prayerId);
      }
    });

    return Scaffold(
        appBar: preferences.readingMode == PrayerReadingMode.immersive 
          ? _buildImmersiveAppBar(context, ref, isFavorite, themeColor, textScaling)
          : AppBar(
              title: Text(
                'Prayer',
                style: textScaling.scaledTitleLarge(context),
              ),
              backgroundColor: themeColor?.withValues(alpha: 0.1),
              actions: [
                IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? (themeColor ?? Colors.red) : null,
                  ),
                  onPressed: () {
                    ref.read(prayerAppSettingsProvider.notifier).toggleFavorite(prayerId);
                  },
                  tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) => _handleMenuAction(value, context, ref),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          const Icon(Icons.share, size: 20),
                          const SizedBox(width: 12),
                          Text('Share Prayer'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'copy',
                      child: Row(
                        children: [
                          const Icon(Icons.copy, size: 20),
                          const SizedBox(width: 12),
                          Text('Copy Text'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'settings',
                      child: Row(
                        children: [
                          const Icon(Icons.settings, size: 20),
                          const SizedBox(width: 12),
                          Text('Reading Settings'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
        body: prayerAsync.when(
              data: (prayer) {
                if (prayer == null) {
                  return const Center(child: Text('Prayer not found'));
                }

                // Create map with all translations (including English)
                final Map<String, String> translations = {
                  'English': prayer.text,
                };

                // Add translations with properly capitalized keys
                prayer.translations?.forEach((key, value) {
                  final capitalizedKey = key[0].toUpperCase() + key.substring(1);
                  translations[capitalizedKey] = value;
                });

                // Get the text to display based on selected language
                final displayText = translations[selectedTranslation] ?? prayer.text;

                return _buildPrayerContent(
                  context, 
                  prayer, 
                  displayText, 
                  translations, 
                  ref, 
                  themeColor, 
                  textScaling,
                  preferences,
                  selectedTranslation,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading prayer',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPrayerContent(
    BuildContext context,
    Prayer prayer,
    String displayText,
    Map<String, String> translations,
    WidgetRef ref,
    Color? themeColor,
    TextScaling textScaling,
    PrayerPreferences preferences,
    String selectedTranslation,
  ) {
    final EdgeInsets padding = preferences.readingMode == PrayerReadingMode.immersive 
        ? const EdgeInsets.symmetric(horizontal: 24, vertical: 32)
        : const EdgeInsets.all(16);

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: preferences.readingMode == PrayerReadingMode.contemplative
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          // Prayer Title (show unless in immersive contemplative mode)
          if (preferences.readingMode != PrayerReadingMode.immersive || 
              preferences.readingMode != PrayerReadingMode.contemplative) ...[
            Text(
              prayer.title,
              style: textScaling.scaledHeadlineMedium(context).copyWith(
                fontWeight: FontWeight.bold,
                color: themeColor,
              ),
              maxLines: textScaling.scaleFactor > 1.2 ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              textAlign: preferences.readingMode == PrayerReadingMode.contemplative
                  ? TextAlign.center
                  : TextAlign.start,
            ),

            // Attribution
            if (prayer.attribution != null) ...[
              SizedBox(height: preferences.readingMode == PrayerReadingMode.immersive ? 12 : 8),
              Text(
                prayer.attribution!,
                style: textScaling.scaledBodyMedium(context).copyWith(
                  fontStyle: FontStyle.italic,
                  color: themeColor?.withValues(alpha: 0.7),
                ),
                textAlign: preferences.readingMode == PrayerReadingMode.contemplative
                    ? TextAlign.center
                    : TextAlign.start,
              ),
            ],

            SizedBox(height: preferences.readingMode == PrayerReadingMode.immersive ? 32 : 24),
          ] else ...[
            // Minimal spacing for contemplative immersive mode
            const SizedBox(height: 16),
          ],

          // Enhanced Prayer Text
          Container(
            padding: preferences.readingMode == PrayerReadingMode.immersive 
                ? const EdgeInsets.all(16)
                : const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: themeColor != null ? Border.all(
                color: themeColor.withValues(alpha: 0.2),
                width: 1,
              ) : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: EnhancedPrayerText(
              text: displayText,
              language: selectedTranslation,
              themeColor: themeColor,
              readingMode: preferences.readingMode,
              enableVerseHighlighting: preferences.verseHighlighting,
            ),
          ),

          // Translation selector (hide in immersive mode)
          if (preferences.readingMode != PrayerReadingMode.immersive && 
              prayer.translations != null && 
              prayer.translations!.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildTranslationSelector(context, prayer, translations, ref, themeColor, textScaling),
          ],

          // Notes (hide in immersive mode unless contemplative)
          if (prayer.notes != null && 
              (preferences.readingMode != PrayerReadingMode.immersive || 
               preferences.readingMode == PrayerReadingMode.contemplative)) ...[
            SizedBox(height: preferences.readingMode == PrayerReadingMode.immersive ? 32 : 24),
            if (preferences.readingMode != PrayerReadingMode.immersive) ...[
              Text(
                'Notes',
                style: textScaling.scaledTitleMedium(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: themeColor ?? Theme.of(context).colorScheme.primary,
                ),
                textAlign: preferences.readingMode == PrayerReadingMode.contemplative
                    ? TextAlign.center
                    : TextAlign.start,
              ),
              const SizedBox(height: 8),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: themeColor?.withValues(alpha: 0.05) ?? 
                       Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                prayer.notes!,
                style: textScaling.scaledBodyMedium(context).copyWith(
                  height: 1.6,
                ),
                textAlign: preferences.readingMode == PrayerReadingMode.contemplative
                    ? TextAlign.center
                    : TextAlign.start,
              ),
            ),
          ],

          // Extra bottom padding for immersive mode
          if (preferences.readingMode == PrayerReadingMode.immersive) 
            const SizedBox(height: 40),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildImmersiveAppBar(
    BuildContext context, 
    WidgetRef ref, 
    bool isFavorite, 
    Color? themeColor, 
    TextScaling textScaling
  ) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      forceMaterialTransparency: true, // Ensures complete transparency
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
      ),
      actions: [
        // Minimal favorite button for immersive mode
        Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite 
                ? (themeColor ?? Colors.red) 
                : Theme.of(context).colorScheme.onSurface,
              size: 18,
            ),
            onPressed: () {
              ref.read(prayerAppSettingsProvider.notifier).toggleFavorite(prayerId);
            },
            tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
          ),
        ),
        // Minimal menu for immersive mode
        Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
            shape: BoxShape.circle,
          ),
          child: PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: Theme.of(context).colorScheme.onSurface,
              size: 18,
            ),
            onSelected: (value) => _handleMenuAction(value, context, ref),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    const Icon(Icons.copy, size: 18),
                    const SizedBox(width: 12),
                    Text('Copy Text', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    const Icon(Icons.settings, size: 18),
                    const SizedBox(width: 12),
                    Text('Settings', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8), // Add some padding from the edge
      ],
    );
  }

  void _handleMenuAction(String action, BuildContext context, WidgetRef ref) {
    switch (action) {
      case 'share':
        // Share functionality would go here
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sharing coming soon')),
        );
        break;
      case 'copy':
        // Copy prayer text functionality
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Text copied to clipboard')),
        );
        break;
      case 'settings':
        // Navigate to settings with reading section highlighted
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
        break;
    }
  }

  Widget _buildTranslationSelector(
      BuildContext context,
      Prayer prayer,
      Map<String, String> translations,
      WidgetRef ref,
      Color? themeColor,
      TextScaling textScaling,
      ) {
    final selectedTranslation = ref.watch(selectedTranslationProvider(prayerId)) ?? ref.watch(prayerDefaultLanguageProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Language',
          style: textScaling.scaledTitleMedium(context).copyWith(
            fontWeight: FontWeight.bold,
            color: themeColor ?? Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: translations.keys.map((language) {
            final isSelected = selectedTranslation == language;

            return ChoiceChip(
              label: Text(
                language,
                style: textScaling.scaledLabelMedium(context),
                overflow: TextOverflow.ellipsis,
              ),
              selected: isSelected,
              selectedColor: themeColor?.withValues(alpha: 0.2),
              onSelected: (selected) {
                if (selected) {
                  ref.read(selectedTranslationProvider(prayerId).notifier).state = language;
                }
              },
              side: isSelected && themeColor != null
                  ? BorderSide(color: themeColor, width: 2)
                  : null,
            );
          }).toList(),
        ),
      ],
    );
  }
}