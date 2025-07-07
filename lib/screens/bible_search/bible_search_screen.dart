import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import '../../providers/app_providers.dart';
import '../../providers/text_scaling_provider.dart';
import '../chapter/chapter_reading_screen.dart';

class BibleSearchScreen extends ConsumerStatefulWidget {
  const BibleSearchScreen({super.key});

  @override
  ConsumerState<BibleSearchScreen> createState() => _BibleSearchScreenState();
}

class _BibleSearchScreenState extends ConsumerState<BibleSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  List<SearchResult> _searchResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() async {
    if (_searchController.text.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchQuery = _searchController.text.trim();
      _searchResults = [];
    });

    // Note: This is a simplified search implementation
    // In a real app, you'd want to implement proper full-text search
    // For now, we'll search through available books and show placeholder results
    
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate search delay

    // Generate mock search results for demonstration
    final mockResults = _generateMockResults(_searchQuery);

    setState(() {
      _isSearching = false;
      _searchResults = mockResults;
    });
  }

  List<SearchResult> _generateMockResults(String query) {
    // This is a simplified mock implementation
    // In a real app, you'd search through the actual Bible text
    final mockResults = <SearchResult>[
      SearchResult(
        book: 'John',
        chapter: 3,
        verse: 16,
        text: 'For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.',
        translation: 'CPDV',
      ),
      SearchResult(
        book: 'Romans',
        chapter: 8,
        verse: 28,
        text: 'And we know that in all things God works for the good of those who love him, who have been called according to his purpose.',
        translation: 'CPDV',
      ),
      SearchResult(
        book: 'Philippians',
        chapter: 4,
        verse: 13,
        text: 'I can do all this through him who gives me strength.',
        translation: 'CPDV',
      ),
      SearchResult(
        book: 'Psalms',
        chapter: 23,
        verse: 1,
        text: 'The Lord is my shepherd, I lack nothing.',
        translation: 'CPDV',
      ),
      SearchResult(
        book: '1 Corinthians',
        chapter: 13,
        verse: 4,
        text: 'Love is patient, love is kind. It does not envy, it does not boast, it is not proud.',
        translation: 'CPDV',
      ),
    ];

    // Filter results that contain the search query (case insensitive)
    return mockResults.where((result) => 
      result.text.toLowerCase().contains(query.toLowerCase()) ||
      result.book.toLowerCase().contains(query.toLowerCase())
    ).toList();
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Search Bible',
          style: textScaling.scaledTitleLarge(context),
        ),
        backgroundColor: themeColor?.withValues(alpha: 0.1),
      ),
      body: Column(
        children: [
          // Search Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: (themeColor ?? Theme.of(context).colorScheme.primary)
                      .withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Search Scripture',
                  style: textScaling.scaledTitleMedium(context).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Find verses, topics, and passages throughout the Bible.',
                  style: textScaling.scaledBodyMedium(context).copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Search Bar
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search for words, phrases, or topics...',
                          prefixIcon: Icon(
                            Icons.search,
                            color: themeColor ?? Theme.of(context).colorScheme.primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: (themeColor ?? Theme.of(context).colorScheme.primary)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: themeColor ?? Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _performSearch(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSearching ? null : _performSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor ?? Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSearching
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text('Search'),
                    ),
                  ],
                ),
                
                // Translation Indicator
                if (_searchQuery.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.translate,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Searching in ${selectedTranslation.name}',
                        style: textScaling.scaledBodySmall(context).copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Search Results
          Expanded(
            child: _buildSearchContent(context, themeColor),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchContent(BuildContext context, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);

    if (_searchQuery.isEmpty) {
      return _buildSearchSuggestions(context, themeColor);
    }

    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: themeColor ?? Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Searching for "$_searchQuery"...',
              style: textScaling.scaledBodyLarge(context).copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: textScaling.scaleFactor * 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'No results found',
                style: textScaling.scaledTitleLarge(context).copyWith(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try searching for different words or phrases.',
                style: textScaling.scaledBodyMedium(context).copyWith(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length + 1, // +1 for results header
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Found ${_searchResults.length} result${_searchResults.length == 1 ? '' : 's'} for "$_searchQuery"',
              style: textScaling.scaledTitleMedium(context).copyWith(
                fontWeight: FontWeight.bold,
                color: themeColor?.withValues(alpha: 0.8) ?? 
                       Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }

        final result = _searchResults[index - 1];
        return _buildSearchResultCard(context, result, themeColor);
      },
    );
  }

  Widget _buildSearchSuggestions(BuildContext context, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    
    final suggestions = [
      'love', 'peace', 'joy', 'hope', 'faith', 'grace',
      'salvation', 'forgiveness', 'wisdom', 'strength'
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Popular Search Terms',
            style: textScaling.scaledTitleMedium(context).copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((suggestion) => GestureDetector(
              onTap: () {
                _searchController.text = suggestion;
                _performSearch();
              },
              child: Chip(
                label: Text(suggestion),
                backgroundColor: (themeColor ?? Theme.of(context).colorScheme.primary)
                    .withValues(alpha: 0.1),
                side: BorderSide(
                  color: (themeColor ?? Theme.of(context).colorScheme.primary)
                      .withValues(alpha: 0.3),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 32),
          Icon(
            Icons.lightbulb_outline,
            size: textScaling.scaleFactor * 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Search Tips:',
            style: textScaling.scaledTitleSmall(context).copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          ...[ 
            '• Search for specific words or phrases',
            '• Try different variations of words',
            '• Search for book names to find passages',
            '• Use shorter, specific terms for better results',
          ].map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              tip,
              style: textScaling.scaledBodyMedium(context).copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildSearchResultCard(BuildContext context, SearchResult result, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToChapter(result.book, result.chapter),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: themeColor != null ? Border.all(
              color: themeColor.withValues(alpha: 0.2),
            ) : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reference
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (themeColor ?? Theme.of(context).colorScheme.primary)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (themeColor ?? Theme.of(context).colorScheme.primary)
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${result.book} ${result.chapter}:${result.verse}',
                        style: textScaling.scaledBodySmall(context).copyWith(
                          fontWeight: FontWeight.bold,
                          color: themeColor?.withValues(alpha: 0.8) ?? 
                                 Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Verse Text
                Text(
                  result.text,
                  style: textScaling.scaledBodyLarge(context).copyWith(
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToChapter(String book, int chapter) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChapterReadingScreen(
          bookName: book,
          chapter: chapter,
        ),
      ),
    );
  }
}

class SearchResult {
  final String book;
  final int chapter;
  final int verse;
  final String text;
  final String translation;

  const SearchResult({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.translation,
  });
}
