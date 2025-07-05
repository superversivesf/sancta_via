import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:bible_data_riverpod/bible_data_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../providers/text_scaling_provider.dart';

/// Debug logging utility
void debugLog(String message, [String? tag]) {
  final timestamp = DateTime.now().toIso8601String();
  print('[$timestamp] ${tag != null ? '[$tag] ' : ''}$message');
}

class ChapterReadingScreen extends ConsumerStatefulWidget {
  final String bookName;
  final int chapter;

  const ChapterReadingScreen({
    super.key,
    required this.bookName,
    required this.chapter,
  });

  @override
  ConsumerState<ChapterReadingScreen> createState() => _ChapterReadingScreenState();
}

class _ChapterReadingScreenState extends ConsumerState<ChapterReadingScreen> {
  late PageController _pageController;
  late String currentBookName;
  late int currentChapter;
  
  @override
  void initState() {
    super.initState();
    currentBookName = widget.bookName;
    currentChapter = widget.chapter;
    _pageController = PageController();
    debugLog('ChapterReadingScreen initialized: $currentBookName $currentChapter', 'CHAPTER');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToChapter(String bookName, int chapter) {
    setState(() {
      currentBookName = bookName;
      currentChapter = chapter;
    });
    debugLog('Navigated to: $bookName $chapter', 'CHAPTER');
  }

  void _navigateToNextChapter() {
    // For now, just increment chapter number
    // In a full implementation, you'd handle book boundaries
    _navigateToChapter(currentBookName, currentChapter + 1);
  }

  void _navigateToPreviousChapter() {
    if (currentChapter > 1) {
      _navigateToChapter(currentBookName, currentChapter - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = ref.watch(currentLiturgicalColorProvider);
    final colorIntensity = ref.watch(colorIntensityProvider);
    final textScaling = ref.watch(textScaleProvider);
    final selectedTranslation = ref.watch(appSelectedBibleTranslationProvider);
    
    // Parse liturgical color and convert to Flutter color
    final liturgicalColor = currentColor != null 
        ? LiturgicalColor.fromString(currentColor)
        : null;
    final themeColor = liturgicalColor?.toFlutterColor(colorIntensity);

    debugLog('Building chapter screen for $currentBookName $currentChapter with ${selectedTranslation.name}', 'CHAPTER');

    // Create scripture reference for current chapter
    final reference = ScriptureReference.chapter(currentBookName, currentChapter);
    final chapterAsync = ref.watch(scriptureByReferenceProvider((
      reference: reference,
      translation: selectedTranslation,
    )));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '$currentBookName $currentChapter',
          style: textScaling.scaledTitleLarge(context),
        ),
        backgroundColor: themeColor?.withValues(alpha: 0.1),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).pushNamed('/settings');
            },
          ),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          // Swipe left to go to next chapter
          if (details.primaryVelocity! < -500) {
            _navigateToNextChapter();
          }
          // Swipe right to go to previous chapter
          else if (details.primaryVelocity! > 500) {
            _navigateToPreviousChapter();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            border: themeColor != null ? Border(
              top: BorderSide(
                color: themeColor.withValues(alpha: 0.3),
                width: 3,
              ),
            ) : null,
          ),
          child: chapterAsync.when(
            data: (scripture) => _buildChapterContent(context, scripture, themeColor),
            loading: () => _buildLoadingContent(context, themeColor),
            error: (error, stack) => _buildErrorContent(context, error, themeColor),
          ),
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous chapter button
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: FloatingActionButton(
              heroTag: "previous",
              onPressed: currentChapter > 1 ? _navigateToPreviousChapter : null,
              backgroundColor: themeColor?.withValues(alpha: 0.8) ?? 
                             Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.chevron_left, color: Colors.white),
            ),
          ),
          // Next chapter button
          FloatingActionButton(
            heroTag: "next",
            onPressed: _navigateToNextChapter,
            backgroundColor: themeColor?.withValues(alpha: 0.8) ?? 
                           Theme.of(context).colorScheme.primary,
            child: const Icon(Icons.chevron_right, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterContent(BuildContext context, ScriptureContent scripture, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    final selectedTranslation = ref.watch(appSelectedBibleTranslationProvider);

    debugLog('Building chapter content: found=${scripture.found}, text length=${scripture.text.length}', 'CHAPTER');

    if (!scripture.found || scripture.text.isEmpty) {
      return _buildNotFoundContent(context, scripture.errorMessage, themeColor);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chapter header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (themeColor ?? Theme.of(context).colorScheme.primary)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (themeColor ?? Theme.of(context).colorScheme.primary)
                    .withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  scripture.reference.displayText,
                  style: textScaling.scaledHeadlineSmall(context).copyWith(
                    fontWeight: FontWeight.bold,
                    color: themeColor?.withValues(alpha: 0.8) ?? 
                           Theme.of(context).colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  selectedTranslation.name,
                  style: textScaling.scaledBodyMedium(context).copyWith(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Chapter text
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (themeColor ?? Theme.of(context).colorScheme.primary)
                    .withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Text(
              scripture.text,
              style: textScaling.scaledBibleText(context, lineHeight: 1.8),
            ),
          ),
          
          const SizedBox(height: 100), // Space for floating action buttons
          
          // Navigation hint
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.swipe_left,
                  size: textScaling.scaleFactor * 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Swipe left/right to navigate chapters',
                  style: textScaling.scaledBodySmall(context).copyWith(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.swipe_right,
                  size: textScaling.scaleFactor * 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingContent(BuildContext context, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: themeColor ?? Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading $currentBookName $currentChapter...',
            style: textScaling.scaledBodyLarge(context).copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorContent(BuildContext context, Object error, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: textScaling.scaleFactor * 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading chapter',
              style: textScaling.scaledTitleLarge(context).copyWith(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: textScaling.scaledBodyMedium(context).copyWith(
                color: Colors.red.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundContent(BuildContext context, String? errorMessage, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: textScaling.scaleFactor * 48,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              'Chapter not found',
              style: textScaling.scaledTitleLarge(context).copyWith(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'The requested chapter could not be loaded.',
              style: textScaling.scaledBodyMedium(context).copyWith(
                color: Colors.orange.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
