import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:bible_data_riverpod/bible_data_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../providers/text_scaling_provider.dart';
import '../../providers/bible_debug_provider.dart';
import '../../providers/book_provider.dart';
import '../settings/settings_screen.dart';
import '../chapter/chapter_reading_screen.dart';

/// Debug logging utility
void debugLog(String message, [String? tag]) {
  final timestamp = DateTime.now().toIso8601String();
  print('[$timestamp] ${tag != null ? '[$tag] ' : ''}$message');
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? selectedBook;
  int selectedChapter = 1;

  @override
  void initState() {
    super.initState();
    selectedBook = 'Mark'; // Default to Mark
    debugLog('HomeScreen initialized with default book: $selectedBook', 'HOME');
  }

  void _navigateToChapter() {
    if (selectedBook != null) {
      debugLog('Navigating to $selectedBook $selectedChapter', 'HOME');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChapterReadingScreen(
            bookName: selectedBook!,
            chapter: selectedChapter,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    debugLog('HomeScreen build called', 'HOME');
    
    // Start debug check
    ref.listen(bibleDebugProvider, (previous, next) {
      next.when(
        data: (data) => debugLog('Bible debug completed: $data', 'HOME'),
        loading: () => debugLog('Bible debug loading...', 'HOME'),
        error: (error, stack) => debugLog('Bible debug error: $error', 'HOME'),
      );
    });
    
    final currentDay = ref.watch(currentLiturgicalDayProvider);
    final currentColor = ref.watch(currentLiturgicalColorProvider);
    final colorIntensity = ref.watch(colorIntensityProvider);
    final textScaling = ref.watch(textScaleProvider);
    final selectedTranslation = ref.watch(appSelectedBibleTranslationProvider);
    final availableBooksAsync = ref.watch(availableBooksProvider);
    final maxChaptersAsync = selectedBook != null ? ref.watch(chapterCountProvider((
      bookName: selectedBook!,
      translation: selectedTranslation,
    ))) : const AsyncValue.data(1);
    
    // Parse liturgical color and convert to Flutter color
    final liturgicalColor = currentColor != null 
        ? LiturgicalColor.fromString(currentColor)
        : null;
    final themeColor = liturgicalColor?.toFlutterColor(colorIntensity);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bible Reading',
          style: textScaling.scaledTitleLarge(context),
        ),
        backgroundColor: themeColor?.withValues(alpha: 0.1),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Liturgical Day Card
            if (currentDay != null) ...[
              Card(
                margin: const EdgeInsets.only(bottom: 24),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: themeColor != null ? Border.all(
                      color: themeColor.withValues(alpha: 0.3),
                      width: 2,
                    ) : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (themeColor != null) ...[
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: themeColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Text(
                                'Today\'s Liturgical Season',
                                style: textScaling.scaledTitleMedium(context).copyWith(
                                  color: themeColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentDay.season,
                          style: textScaling.scaledHeadlineSmall(context).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (currentDay.celebration.name.isNotEmpty && 
                            currentDay.celebration.name != currentDay.season) ...[
                          const SizedBox(height: 4),
                          Text(
                            currentDay.celebration.name,
                            style: textScaling.scaledBodyLarge(context),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // Bible Reading Selection Header
            Text(
              'Select Scripture to Read',
              style: textScaling.scaledHeadlineSmall(context).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Bible Selection Card
            Card(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: themeColor != null ? Border.all(
                    color: themeColor.withValues(alpha: 0.3),
                    width: 2,
                  ) : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with translation selector
                      Row(
                        children: [
                          Icon(
                            Icons.auto_stories,
                            color: themeColor ?? Theme.of(context).colorScheme.primary,
                            size: textScaling.scaleFactor * 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Choose Book & Chapter',
                              style: textScaling.scaledTitleMedium(context).copyWith(
                                fontWeight: FontWeight.bold,
                                color: themeColor?.withValues(alpha: 0.8) ?? 
                                       Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          // Translation selector
                          DropdownButton<BibleTranslation>(
                            value: selectedTranslation,
                            onChanged: (BibleTranslation? newValue) {
                              if (newValue != null) {
                                ref.read(appSettingsProvider.notifier).setBibleTranslation(newValue);
                              }
                            },
                            items: BibleTranslation.values.map((translation) {
                              return DropdownMenuItem(
                                value: translation,
                                child: Text(
                                  translation.abbreviation,
                                  style: textScaling.scaledBodyMedium(context),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Book selection
                      Text(
                        'Book:',
                        style: textScaling.scaledTitleSmall(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: themeColor?.withValues(alpha: 0.7) ?? 
                                 Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: (themeColor ?? Theme.of(context).colorScheme.primary)
                                .withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: availableBooksAsync.when(
                          data: (availableBooks) {
                            // Ensure selected book is valid
                            if (selectedBook != null && !availableBooks.contains(selectedBook)) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                setState(() {
                                  selectedBook = availableBooks.isNotEmpty ? availableBooks.first : null;
                                  selectedChapter = 1;
                                });
                              });
                            }
                            
                            return DropdownButton<String>(
                              value: availableBooks.contains(selectedBook) ? selectedBook : null,
                              isExpanded: true,
                              underline: Container(),
                              hint: Text(
                                availableBooks.isEmpty ? 'Loading books...' : 'Select a book...',
                                style: textScaling.scaledBodyMedium(context),
                              ),
                              onChanged: availableBooks.isNotEmpty ? (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    selectedBook = newValue;
                                    selectedChapter = 1; // Reset to chapter 1 when book changes
                                  });
                                  debugLog('Selected book: $newValue', 'HOME');
                                }
                              } : null,
                              items: availableBooks.map((book) {
                                return DropdownMenuItem(
                                  value: book,
                                  child: Text(
                                    book,
                                    style: textScaling.scaledBodyMedium(context),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                          loading: () => Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: themeColor ?? Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Loading books...',
                                  style: textScaling.scaledBodyMedium(context),
                                ),
                              ],
                            ),
                          ),
                          error: (error, stack) => Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'Error loading books',
                              style: textScaling.scaledBodyMedium(context).copyWith(
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Chapter selection
                      Row(
                        children: [
                          Text(
                            'Chapter:',
                            style: textScaling.scaledTitleSmall(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: themeColor?.withValues(alpha: 0.7) ?? 
                                     Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Chapter number input
                          Container(
                            width: 80,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: (themeColor ?? Theme.of(context).colorScheme.primary)
                                    .withValues(alpha: 0.3),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextFormField(
                              initialValue: selectedChapter.toString(),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 8),
                              ),
                              onChanged: (value) {
                                final chapter = int.tryParse(value);
                                if (chapter != null && chapter > 0) {
                                  // Basic validation - detailed validation happens when maxChapters loads
                                  setState(() {
                                    selectedChapter = chapter;
                                  });
                                  debugLog('Selected chapter: $chapter', 'HOME');
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Chapter range indicator
                          maxChaptersAsync.when(
                            data: (maxChapters) => Text(
                              '(1-$maxChapters)',
                              style: textScaling.scaledBodySmall(context).copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            loading: () => Text(
                              '(1-?)',
                              style: textScaling.scaledBodySmall(context).copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            error: (error, stack) => Text(
                              '(1-1)',
                              style: textScaling.scaledBodySmall(context).copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Quick chapter buttons
                          maxChaptersAsync.when(
                            data: (maxChapters) => Row(
                              children: [
                                IconButton(
                                  onPressed: selectedChapter > 1 ? () {
                                    setState(() {
                                      selectedChapter--;
                                    });
                                  } : null,
                                  icon: const Icon(Icons.remove),
                                  tooltip: 'Previous chapter',
                                ),
                                IconButton(
                                  onPressed: selectedChapter < maxChapters ? () {
                                    setState(() {
                                      selectedChapter++;
                                    });
                                  } : null,
                                  icon: const Icon(Icons.add),
                                  tooltip: 'Next chapter',
                                ),
                              ],
                            ),
                            loading: () => Row(
                              children: [
                                IconButton(
                                  onPressed: selectedChapter > 1 ? () {
                                    setState(() {
                                      selectedChapter--;
                                    });
                                  } : null,
                                  icon: const Icon(Icons.remove),
                                  tooltip: 'Previous chapter',
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      selectedChapter++;
                                    });
                                  },
                                  icon: const Icon(Icons.add),
                                  tooltip: 'Next chapter',
                                ),
                              ],
                            ),
                            error: (error, stack) => Row(
                              children: [
                                IconButton(
                                  onPressed: null,
                                  icon: const Icon(Icons.remove),
                                  tooltip: 'Previous chapter',
                                ),
                                IconButton(
                                  onPressed: null,
                                  icon: const Icon(Icons.add),
                                  tooltip: 'Next chapter',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Read button
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: selectedBook != null ? _navigateToChapter : null,
                          icon: const Icon(Icons.menu_book),
                          label: Text(
                            'Read Chapter',
                            style: textScaling.scaledBodyLarge(context).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeColor ?? Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      
                      // Current selection display
                      if (selectedBook != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (themeColor ?? Theme.of(context).colorScheme.primary)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (themeColor ?? Theme.of(context).colorScheme.primary)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: maxChaptersAsync.when(
                            data: (maxChapters) => Text(
                              'Ready to read: $selectedBook $selectedChapter of $maxChapters (${selectedTranslation.abbreviation})',
                              style: textScaling.scaledBodyMedium(context).copyWith(
                                fontWeight: FontWeight.w500,
                                color: themeColor?.withValues(alpha: 0.8) ??
                                       Theme.of(context).colorScheme.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            loading: () => Text(
                              'Ready to read: $selectedBook $selectedChapter (${selectedTranslation.abbreviation})',
                              style: textScaling.scaledBodyMedium(context).copyWith(
                                fontWeight: FontWeight.w500,
                                color: themeColor?.withValues(alpha: 0.8) ??
                                       Theme.of(context).colorScheme.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            error: (error, stack) => Text(
                              'Ready to read: $selectedBook $selectedChapter (${selectedTranslation.abbreviation})',
                              style: textScaling.scaledBodyMedium(context).copyWith(
                                fontWeight: FontWeight.w500,
                                color: themeColor?.withValues(alpha: 0.8) ??
                                       Theme.of(context).colorScheme.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
