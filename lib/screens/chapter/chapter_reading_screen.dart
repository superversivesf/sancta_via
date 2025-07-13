import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:bible_data_riverpod/bible_data_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../providers/text_scaling_provider.dart';
import '../../providers/book_provider.dart';

/// Debug logging utility
void debugLog(String message, [String? tag]) {
  final timestamp = DateTime.now().toIso8601String();
  // ignore: avoid_print
  print('[$timestamp] ${tag != null ? '[$tag] ' : ''}$message');
}

class ChapterReadingScreen extends ConsumerStatefulWidget {
  final String bookName;
  final int chapter;
  final int? startVerse; // Optional starting verse

  const ChapterReadingScreen({
    required this.bookName, required this.chapter, super.key,
    this.startVerse,
  });

  @override
  ConsumerState<ChapterReadingScreen> createState() => _ChapterReadingScreenState();
}

class _ChapterReadingScreenState extends ConsumerState<ChapterReadingScreen> {
  late PageController _pageController;
  late ScrollController _scrollController;
  late String currentBookName;
  late int currentChapter;
  String _currentChapterText = ''; // Store for debugging
  bool _hasScrolledToInitialVerse = false; // Track if we've scrolled to the initial verse
  
  @override
  void initState() {
    super.initState();
    currentBookName = widget.bookName;
    currentChapter = widget.chapter;
    _pageController = PageController();
    _scrollController = ScrollController();
    debugLog('ChapterReadingScreen initialized: $currentBookName $currentChapter${widget.startVerse != null ? ' (starting at verse ${widget.startVerse})' : ''}', 'CHAPTER');
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _navigateToChapter(String bookName, int chapter) {
    setState(() {
      currentBookName = bookName;
      currentChapter = chapter;
      // Reset the scroll flag when navigating to a different chapter
      // so we don't scroll to the original startVerse in the new chapter
      _hasScrolledToInitialVerse = true; 
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
    
    // Get max chapters for navigation logic
    final maxChaptersAsync = ref.watch(chapterCountProvider((
      bookName: currentBookName,
      translation: selectedTranslation,
    )));
    
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
              context.push('/settings');
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
        child: SafeArea(
          top: false, // Let AppBar handle top
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
      ),
      floatingActionButton: maxChaptersAsync.when(
        data: (maxChapters) => _buildNavigationButtons(context, maxChapters, themeColor),
        loading: () => null, // Don't show buttons while loading
        error: (error, stackTrace) => null, // Don't show buttons on error
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

    // Schedule scroll to starting verse after the content is built
    // Only do this once, when we first load the original chapter with the startVerse
    if (widget.startVerse != null && 
        widget.startVerse! > 1 && 
        !_hasScrolledToInitialVerse &&
        currentBookName == widget.bookName &&
        currentChapter == widget.chapter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToVerse(widget.startVerse!);
        _hasScrolledToInitialVerse = true; // Mark that we've scrolled
      });
    }

    return SingleChildScrollView(
      controller: _scrollController,
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
          
          // Chapter text with verse formatting
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
            child: _buildFormattedChapterText(context, scripture.text, themeColor),
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

  Widget _buildFormattedChapterText(BuildContext context, String chapterText, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    _currentChapterText = chapterText; // Store for debugging
    final verses = _parseVersesFromChapter(chapterText);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: verses.asMap().entries.map((entry) {
        final verseNumber = entry.key + 1;
        final verseText = entry.value;
        
        return Container(
          key: ValueKey('verse_$verseNumber'), // For potential future scrolling improvements
          margin: const EdgeInsets.only(bottom: 12),
          child: RichText(
            text: TextSpan(
              style: textScaling.scaledBibleText(context, lineHeight: 1.8),
              children: [
                TextSpan(
                  text: '$verseNumber ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.8),
                    fontSize: textScaling.scaledBibleText(context).fontSize! * 0.9,
                  ),
                ),
                TextSpan(
                  text: verseText,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  List<String> _parseVersesFromChapter(String chapterText) {
    final verses = <String>[];
    
    // Try to split by verse numbers (pattern: number followed by space)
    final versePattern = RegExp(r'(?:^|\s)(\d+)\s+([^0-9]*?)(?=\s\d+\s|$)', multiLine: true);
    final matches = versePattern.allMatches(chapterText);
    
    if (matches.isNotEmpty) {
      // Found verse patterns, use them
      for (final match in matches) {
        final verseText = match.group(2)?.trim() ?? '';
        if (verseText.isNotEmpty) {
          verses.add(verseText);
        }
      }
    } else {
      // Fallback: split by sentences and group them
      final sentences = chapterText.split(RegExp(r'[.!?]+\s+'));
      
      // Group sentences into reasonable verse-like chunks
      for (int i = 0; i < sentences.length; i += 2) {
        final verseText = sentences.sublist(i, (i + 2).clamp(0, sentences.length)).join('. ').trim();
        if (verseText.isNotEmpty) {
          verses.add(verseText);
        }
      }
    }
    
    // Ensure we have at least one verse
    if (verses.isEmpty) {
      verses.add(chapterText.isNotEmpty ? chapterText : 'Chapter text');
    }
    
    return verses;
  }

  void _scrollToVerse(int startVerse) {
    if (!_scrollController.hasClients) return;
    
    try {
      // Get current scroll information for debugging
      final currentPosition = _scrollController.position;
      final maxScrollExtent = currentPosition.maxScrollExtent;
      final viewportHeight = currentPosition.viewportDimension;
      final initialOffset = currentPosition.pixels;
      
      debugLog('=== SCROLL DEBUG INFO ===', 'CHAPTER');
      debugLog('Target verse: $startVerse', 'CHAPTER');
      debugLog('Current scroll offset: $initialOffset', 'CHAPTER');
      debugLog('Max scroll extent: $maxScrollExtent', 'CHAPTER');
      debugLog('Viewport height: $viewportHeight', 'CHAPTER');
      
      // Let's try a different approach - use a percentage of the total content
      // Get the total number of verses we parsed
      final totalVerses = _parseVersesFromChapter(_getCurrentChapterText()).length;
      debugLog('Total verses parsed: $totalVerses', 'CHAPTER');
      
      if (totalVerses == 0 || startVerse > totalVerses) {
        debugLog('Invalid verse number or no verses found', 'CHAPTER');
        return;
      }
      
      // Calculate what percentage through the content this verse represents
      final verseProgress = (startVerse - 1) / totalVerses;
      debugLog('Verse progress: $verseProgress (${(verseProgress * 100).toStringAsFixed(1)}%)', 'CHAPTER');
      
      // Apply this percentage to the scrollable content
      // Leave some room at the top (header) - estimate 300px for header + padding
      const estimatedHeaderHeight = 300.0;
      final scrollableContent = maxScrollExtent - estimatedHeaderHeight;
      final targetPosition = estimatedHeaderHeight + (scrollableContent * verseProgress);
      
      debugLog('Estimated header height: $estimatedHeaderHeight', 'CHAPTER');
      debugLog('Scrollable content: $scrollableContent', 'CHAPTER');
      debugLog('Calculated target position: $targetPosition', 'CHAPTER');
      
      // Clamp to valid range
      final clampedPosition = targetPosition.clamp(0.0, maxScrollExtent);
      debugLog('Clamped position: $clampedPosition', 'CHAPTER');
      
      // Scroll to the calculated position
      _scrollController.animateTo(
        clampedPosition,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
      
      // Log the final position after a delay
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (_scrollController.hasClients) {
          final finalPosition = _scrollController.position.pixels;
          debugLog('Final scroll position: $finalPosition', 'CHAPTER');
          debugLog('=== END SCROLL DEBUG ===', 'CHAPTER');
        }
      });
      
    } catch (e) {
      debugLog('Error scrolling to verse: $e', 'CHAPTER');
    }
  }

  String _getCurrentChapterText() {
    return _currentChapterText;
  }

  Widget? _buildNavigationButtons(BuildContext context, int maxChapters, Color? themeColor) {
    final showPrevious = currentChapter > 1;
    final showNext = currentChapter < maxChapters;
    
    // If neither button should be shown, return null
    if (!showPrevious && !showNext) {
      return null;
    }
    
    // Always use the same layout but conditionally show buttons
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Previous chapter button (always in same position)
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: showPrevious
              ? FloatingActionButton(
                  heroTag: 'previous',
                  onPressed: _navigateToPreviousChapter,
                  backgroundColor: themeColor?.withValues(alpha: 0.8) ?? 
                                 Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.chevron_left, color: Colors.white),
                )
              : const SizedBox.shrink(), // Invisible placeholder
        ),
        // Next chapter button (always in same position)
        showNext
            ? FloatingActionButton(
                heroTag: 'next',
                onPressed: _navigateToNextChapter,
                backgroundColor: themeColor?.withValues(alpha: 0.8) ?? 
                               Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.chevron_right, color: Colors.white),
              )
            : const SizedBox.shrink(), // Invisible placeholder
      ],
    );
  }
}
