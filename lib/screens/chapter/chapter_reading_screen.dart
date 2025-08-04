import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for clipboard functionality
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:bible_data_riverpod/bible_data_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../providers/text_scaling_provider.dart';
import '../../providers/reading_plan_provider.dart';

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
  bool _hasScrolledToInitialVerse = false; // Track if we've scrolled to the initial verse
  
  // Verse scrolling management
  final List<GlobalKey> _verseKeys = [];
  List<String> _currentVerses = [];
  
  @override
  void initState() {
    super.initState();
    currentBookName = widget.bookName;
    currentChapter = widget.chapter;
    _pageController = PageController();
    _scrollController = ScrollController();
    debugLog('ChapterReadingScreen initialized: $currentBookName $currentChapter${widget.startVerse != null ? ' (starting at verse ${widget.startVerse})' : ''}', 'CHAPTER');
    
    // Check if this chapter visit should mark a reading plan as complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndMarkReadingPlanComplete();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Check if visiting this chapter should mark any reading plan as complete
  void _checkAndMarkReadingPlanComplete() {
    final activePlans = ref.read(activeReadingPlansProvider);
    
    for (final plan in activePlans) {
      // Check if this chapter matches the plan's current reading
      if (plan.progress.currentBook == currentBookName && 
          !plan.hasReadToday) {
        
        // Check if the current chapter is within the plan's reading range for today
        final startChapter = plan.progress.currentChapter;
        final endChapter = startChapter + plan.chaptersPerDay - 1;
        
        if (currentChapter >= startChapter && currentChapter <= endChapter) {
          // This chapter visit counts toward this reading plan
          ref.read(readingPlanManagerProvider.notifier).markCurrentReadingAsComplete(plan.id);
          debugLog('Marked reading plan "${plan.name}" as complete for visiting $currentBookName $currentChapter', 'CHAPTER');
          break; // Only mark one plan to avoid conflicts
        }
      }
    }
  }

  void _navigateToChapter(String bookName, int chapter) {
    setState(() {
      currentBookName = bookName;
      currentChapter = chapter;
      // Reset the scroll flag when navigating to a different chapter
      // so we don't scroll to the original startVerse in the new chapter
      _hasScrolledToInitialVerse = true;
      // Clear verse keys for new chapter
      _verseKeys.clear();
      _currentVerses.clear();
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
    
    // Get max chapters for navigation logic (using optimized provider)
    final maxChaptersAsync = ref.watch(optimizedChapterCountProvider((
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
    final chapterAsync = ref.watch(optimizedScriptureByReferenceProvider((
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
          final velocity = details.primaryVelocity;
          if (velocity != null) {
            // Swipe left to go to next chapter
            if (velocity < -500) {
              _navigateToNextChapter();
            }
            // Swipe right to go to previous chapter
            else if (velocity > 500) {
              _navigateToPreviousChapter();
            }
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

  Widget _buildChapterContent(BuildContext context, OptimizedScriptureContent scripture, Color? themeColor) {
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
        _scrollToVerseAccurate(widget.startVerse!);
        _hasScrolledToInitialVerse = true; // Mark that we've scrolled
      });
    }

    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
          (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.6)
        ),
        trackColor: WidgetStateProperty.all(
          (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.1)
        ),
        trackBorderColor: WidgetStateProperty.all(Colors.transparent),
        thickness: WidgetStateProperty.all(6.0),
        radius: const Radius.circular(3.0),
        crossAxisMargin: 2.0,
        mainAxisMargin: 4.0,
      ),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true, // Always show the scroll thumb for progress indication
        trackVisibility: true, // Show a subtle track for better visual guidance
        child: SingleChildScrollView(
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
            
            // Chapter text with verse formatting and selection capability
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
              child: _buildSelectableChapterText(context, scripture.text, themeColor),
            ),
            
            const SizedBox(height: 24),
            
            // Selection instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.content_copy,
                        size: 16,
                        color: themeColor ?? Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'How to copy verses:',
                          style: textScaling.scaledBodySmall(context).copyWith(
                            color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.8),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Tap any verse to copy it\n2. The entire verse will be copied to clipboard\n3. Paste in any other app to share',
                    style: textScaling.scaledBodySmall(context).copyWith(
                      color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
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
      ),
    ),
  );
  }

  /// Build selectable chapter text with verse formatting
  Widget _buildSelectableChapterText(BuildContext context, String chapterText, Color? themeColor) {
    final verses = _parseVersesFromChapter(chapterText);
    
    // Generate keys for each verse if needed
    _generateVerseKeys(verses.length);
    _currentVerses = verses;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: verses.asMap().entries.map((entry) {
        final verseNumber = entry.key + 1;
        final verseText = entry.value;
        
        return _buildTappableVerse(context, verseNumber, verseText, themeColor, entry.key);
      }).toList(),
    );
  }
  
  /// Build a tappable verse that highlights and copies when tapped
  Widget _buildTappableVerse(BuildContext context, int verseNumber, String verseText, Color? themeColor, int index) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Container(
      key: _verseKeys[index], // Use GlobalKey for precise scrolling
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _handleVerseTap(verseNumber, verseText),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.transparent,
              width: 2,
            ),
          ),
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
        ),
      ),
    );
  }
  
  /// Handle when a verse is tapped - highlight and copy
  void _handleVerseTap(int verseNumber, String verseText) async {
    final selectedTranslation = ref.read(appSelectedBibleTranslationProvider);
    
    // Create formatted text for clipboard
    final translationAbbrev = selectedTranslation.abbreviation;
    final formattedText = '$verseText ($currentBookName $currentChapter:$verseNumber, ${translationAbbrev ?? 'Bible'})';
    
    // Copy to clipboard
    try {
      await Clipboard.setData(ClipboardData(text: formattedText));
      
      // Provide haptic feedback
      HapticFeedback.lightImpact();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.content_copy, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Copied verse $verseNumber to clipboard'),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
      
      debugLog('Successfully copied verse $verseNumber to clipboard', 'VERSE_TAP');
    } catch (e) {
      debugLog('Error copying verse to clipboard: $e', 'VERSE_TAP');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to copy verse to clipboard'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  void _scrollToVerseAccurate(int startVerse) {
    if (startVerse <= 0 || startVerse > _verseKeys.length) {
      debugLog('Invalid verse number: $startVerse (available: ${_verseKeys.length})', 'CHAPTER');
      return;
    }
    
    final verseIndex = startVerse - 1; // Convert to 0-based index
    final verseKey = _verseKeys[verseIndex];
    
    debugLog('=== ACCURATE SCROLL DEBUG ===', 'CHAPTER');
    debugLog('Target verse: $startVerse (index: $verseIndex)', 'CHAPTER');
    debugLog('Total verses: ${_verseKeys.length}', 'CHAPTER');
    
    // Wait for the widget to be built and rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = verseKey.currentContext;
      if (context != null) {
        // Adjust alignment for verses near the end
        double alignment = 0.15; // Default: 15% from top
        
        // If this is in the last 20% of verses, center it instead
        if (startVerse > (_verseKeys.length * 0.8)) {
          alignment = 0.5; // Center it for better visibility
          debugLog('Using center alignment for verse near end', 'CHAPTER');
        }
        
        debugLog('Scrolling to verse with alignment: $alignment', 'CHAPTER');
        
        try {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            alignment: alignment,
          );
          
          debugLog('Successfully initiated scroll to verse $startVerse', 'CHAPTER');
        } catch (e) {
          debugLog('Error during ensureVisible: $e', 'CHAPTER');
        }
      } else {
        debugLog('Verse context not found for verse $startVerse', 'CHAPTER');
      }
      
      debugLog('=== END ACCURATE SCROLL DEBUG ===', 'CHAPTER');
    });
  }
  
  
  /// Generate GlobalKeys for each verse for precise scrolling
  void _generateVerseKeys(int verseCount) {
    // Only regenerate if the count has changed
    if (_verseKeys.length != verseCount) {
      _verseKeys.clear();
      _verseKeys.addAll(List.generate(verseCount, (index) => GlobalKey()));
      debugLog('Generated ${_verseKeys.length} verse keys', 'CHAPTER');
    }
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
