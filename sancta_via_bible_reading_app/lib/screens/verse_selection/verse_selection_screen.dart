import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:bible_data_riverpod/bible_data_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/app_providers.dart';
import '../../providers/text_scaling_provider.dart';

class VerseSelectionScreen extends ConsumerWidget {
  final String bookName;
  final int chapter;

  const VerseSelectionScreen({
    required this.bookName,
    required this.chapter,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentColor = ref.watch(currentLiturgicalColorProvider);
    final colorIntensity = ref.watch(colorIntensityProvider);
    final textScaling = ref.watch(textScaleProvider);
    final selectedTranslation = ref.watch(appSelectedBibleTranslationProvider);

    // Get chapter content to count verses
    final reference = ScriptureReference.chapter(bookName, chapter);
    final chapterAsync = ref.watch(
      scriptureByReferenceProvider((
        reference: reference,
        translation: selectedTranslation,
      )),
    );

    // Parse liturgical color and convert to Flutter color
    final liturgicalColor = currentColor != null
        ? LiturgicalColor.fromString(currentColor)
        : null;
    final themeColor = liturgicalColor?.toFlutterColor(colorIntensity);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '$bookName $chapter',
          style: textScaling.scaledTitleLarge(context),
        ),
        backgroundColor: themeColor?.withValues(alpha: 0.1),
        actions: [
          // Translation indicator
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (themeColor ?? Theme.of(context).colorScheme.primary)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (themeColor ?? Theme.of(context).colorScheme.primary)
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              selectedTranslation.abbreviation,
              style: textScaling
                  .scaledBodySmall(context)
                  .copyWith(
                    fontWeight: FontWeight.w600,
                    color: themeColor ?? Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false, // Let AppBar handle top
        child: chapterAsync.when(
          data: (scripture) =>
              _buildVerseGrid(context, ref, scripture, themeColor),
          loading: () => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: themeColor ?? Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading verses for $bookName $chapter...',
                  style: textScaling.scaledBodyLarge(context),
                ),
              ],
            ),
          ),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading verses',
                  style: textScaling
                      .scaledTitleMedium(context)
                      .copyWith(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: textScaling.scaledBodyMedium(context),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerseGrid(
    BuildContext context,
    WidgetRef ref,
    ScriptureContent scripture,
    Color? themeColor,
  ) {
    final textScaling = ref.watch(textScaleProvider);

    if (!scripture.found || scripture.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              'Chapter not found',
              style: textScaling
                  .scaledTitleMedium(context)
                  .copyWith(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      );
    }

    // True verse numbers come from the structured verses on the content.
    final verseCount = scripture.verses.length;

    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (themeColor ?? Theme.of(context).colorScheme.primary)
                .withValues(alpha: 0.05),
            border: Border(
              bottom: BorderSide(
                color: (themeColor ?? Theme.of(context).colorScheme.primary)
                    .withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Column(
            children: [
              Text(
                'Select Verse',
                style: textScaling
                    .scaledTitleMedium(context)
                    .copyWith(
                      fontWeight: FontWeight.bold,
                      color:
                          themeColor?.withValues(alpha: 0.8) ??
                          Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '$bookName $chapter has $verseCount verses',
                style: textScaling
                    .scaledBodyMedium(context)
                    .copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        ),

        // Verse Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8, // 8 verses per row (smaller tiles)
              childAspectRatio: 1.0,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: verseCount,
            itemBuilder: (context, index) {
              // The tile's label AND navigation target use the TRUE verse
              // number from the structured verses (not index + 1).
              final verseNumber = scripture.verses[index].number;

              return Card(
                elevation: 2,
                child: InkWell(
                  onTap: () =>
                      _navigateToChapterWithVerse(context, verseNumber),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            (themeColor ??
                                    Theme.of(context).colorScheme.primary)
                                .withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        verseNumber.toString(),
                        style: textScaling
                            .scaledBodyLarge(context)
                            .copyWith(
                              fontWeight: FontWeight.bold,
                              color:
                                  themeColor ??
                                  Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Quick actions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: (themeColor ?? Theme.of(context).colorScheme.primary)
                    .withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _navigateToChapterWithVerse(context, 1),
                  icon: const Icon(Icons.first_page),
                  label: const Text('Start at Verse 1'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        themeColor ?? Theme.of(context).colorScheme.primary,
                    side: BorderSide(
                      color:
                          (themeColor ?? Theme.of(context).colorScheme.primary)
                              .withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToChapterFromBeginning(context),
                  icon: const Icon(Icons.menu_book),
                  label: const Text('Read Whole Chapter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        themeColor ?? Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToChapterWithVerse(BuildContext context, int startVerse) {
    context.push(
      '/chapter/${Uri.encodeComponent(bookName)}/$chapter?startVerse=$startVerse',
    );
  }

  void _navigateToChapterFromBeginning(BuildContext context) {
    context.push('/chapter/${Uri.encodeComponent(bookName)}/$chapter');
  }
}
