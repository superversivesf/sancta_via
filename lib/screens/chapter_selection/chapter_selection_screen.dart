import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import '../../providers/app_providers.dart';
import '../../providers/text_scaling_provider.dart';
import '../../providers/book_provider.dart';
import '../verse_selection/verse_selection_screen.dart';
import '../chapter/chapter_reading_screen.dart';

class ChapterSelectionScreen extends ConsumerWidget {
  final String bookName;

  const ChapterSelectionScreen({
    required this.bookName, super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentColor = ref.watch(currentLiturgicalColorProvider);
    final colorIntensity = ref.watch(colorIntensityProvider);
    final textScaling = ref.watch(textScaleProvider);
    final selectedTranslation = ref.watch(appSelectedBibleTranslationProvider);
    final maxChaptersAsync = ref.watch(chapterCountProvider((
      bookName: bookName,
      translation: selectedTranslation,
    )));
    
    // Parse liturgical color and convert to Flutter color
    final liturgicalColor = currentColor != null 
        ? LiturgicalColor.fromString(currentColor)
        : null;
    final themeColor = liturgicalColor?.toFlutterColor(colorIntensity);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          bookName,
          style: textScaling.scaledTitleLarge(context),
        ),
        backgroundColor: themeColor?.withValues(alpha: 0.1),
        actions: [
          // Translation indicator
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              selectedTranslation.abbreviation,
              style: textScaling.scaledBodySmall(context).copyWith(
                fontWeight: FontWeight.w600,
                color: themeColor ?? Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      body: maxChaptersAsync.when(
        data: (maxChapters) => _buildChapterGrid(context, ref, maxChapters, themeColor),
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: themeColor ?? Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading chapters for $bookName...',
                style: textScaling.scaledBodyLarge(context),
              ),
            ],
          ),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading chapters',
                style: textScaling.scaledTitleMedium(context).copyWith(
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
    );
  }

  Widget _buildChapterGrid(BuildContext context, WidgetRef ref, int maxChapters, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.05),
            border: Border(
              bottom: BorderSide(
                color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Column(
            children: [
              Text(
                'Select Chapter',
                style: textScaling.scaledTitleMedium(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: themeColor?.withValues(alpha: 0.8) ?? Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$bookName has $maxChapters chapter${maxChapters == 1 ? '' : 's'}',
                style: textScaling.scaledBodyMedium(context).copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        
        // Chapter Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6, // 6 chapters per row (smaller tiles)
              childAspectRatio: 1.0,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: maxChapters,
            itemBuilder: (context, index) {
              final chapterNumber = index + 1;
              
              return Card(
                elevation: 2,
                child: InkWell(
                  onTap: () => _navigateToVerseSelection(context, chapterNumber),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        chapterNumber.toString(),
                        style: textScaling.scaledTitleMedium(context).copyWith(
                          fontWeight: FontWeight.bold,
                          color: themeColor ?? Theme.of(context).colorScheme.primary,
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
                color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _navigateToChapter(context, 1),
                  icon: const Icon(Icons.first_page),
                  label: const Text('Read from Chapter 1'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: themeColor ?? Theme.of(context).colorScheme.primary,
                    side: BorderSide(
                      color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: maxChapters > 0 ? () => _navigateToChapter(context, maxChapters) : null,
                  icon: const Icon(Icons.last_page),
                  label: const Text('Last Chapter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor ?? Theme.of(context).colorScheme.primary,
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

  void _navigateToVerseSelection(BuildContext context, int chapter) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VerseSelectionScreen(
          bookName: bookName,
          chapter: chapter,
        ),
      ),
    );
  }

  void _navigateToChapter(BuildContext context, int chapter) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChapterReadingScreen(
          bookName: bookName,
          chapter: chapter,
        ),
      ),
    );
  }
}
