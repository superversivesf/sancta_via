import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:bible_data_riverpod/bible_data_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../providers/text_scaling_provider.dart';

class BibleSearchScreen extends ConsumerStatefulWidget {
  const BibleSearchScreen({super.key});

  @override
  ConsumerState<BibleSearchScreen> createState() => _BibleSearchScreenState();
}

class _BibleSearchScreenState extends ConsumerState<BibleSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showAdvancedOptions = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    if (_searchController.text.trim().isEmpty) return;

    final query = _searchController.text.trim();
    
    // Add to search history
    ref.read(searchHistoryProvider.notifier).addSearch(query);
    
    // Perform the search using the search state provider
    ref.read(searchStateProvider.notifier).search(query);
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchStateProvider.notifier).clear();
  }

  void _searchFromSuggestion(String query) {
    _searchController.text = query;
    _performSearch();
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = ref.watch(currentLiturgicalColorProvider);
    final colorIntensity = ref.watch(colorIntensityProvider);
    final textScaling = ref.watch(textScaleProvider);
    final selectedTranslation = ref.watch(appSelectedBibleTranslationProvider);
    final searchState = ref.watch(searchStateProvider);
    final searchSettings = ref.watch(searchSettingsProvider);
    
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
        actions: [
          if (searchState.query != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearSearch,
              tooltip: 'Clear search',
            ),
          IconButton(
            icon: Icon(_showAdvancedOptions ? Icons.expand_less : Icons.expand_more),
            onPressed: () {
              setState(() {
                _showAdvancedOptions = !_showAdvancedOptions;
              });
            },
            tooltip: 'Search options',
          ),
        ],
      ),
      body: SafeArea(
        top: false, // Let AppBar handle top
        child: Column(
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
                      onPressed: (searchState is SearchStateLoading) ? null : _performSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor ?? Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: (searchState is SearchStateLoading)
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Search'),
                    ),
                  ],
                ),
                
                // Translation Indicator
                if (searchState.query != null) ...[
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

                // Advanced Options
                if (_showAdvancedOptions) ...[
                  const SizedBox(height: 16),
                  _buildAdvancedOptions(context, searchSettings, themeColor),
                ],
              ],
            ),
          ),

            // Search Results
            Expanded(
              child: _buildSearchContent(context, searchState, themeColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedOptions(BuildContext context, SearchSettings searchSettings, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    final searchSettingsNotifier = ref.read(searchSettingsProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search Options',
            style: textScaling.scaledTitleSmall(context).copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Search option switches
          _buildSearchOption(
            context,
            'Case sensitive',
            searchSettings.caseSensitive,
            searchSettingsNotifier.toggleCaseSensitive,
            themeColor,
          ),
          _buildSearchOption(
            context,
            'Whole words only',
            searchSettings.wholeWords,
            searchSettingsNotifier.toggleWholeWords,
            themeColor,
          ),
          _buildSearchOption(
            context,
            'Old Testament only',
            searchSettings.oldTestamentOnly,
            searchSettingsNotifier.toggleOldTestamentOnly,
            themeColor,
          ),
          _buildSearchOption(
            context,
            'New Testament only',
            searchSettings.newTestamentOnly,
            searchSettingsNotifier.toggleNewTestamentOnly,
            themeColor,
          ),
          
          const SizedBox(height: 8),
          
          // Max results slider
          Text(
            'Max results: ${searchSettings.maxResults}',
            style: textScaling.scaledBodySmall(context).copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          Slider(
            value: searchSettings.maxResults.toDouble(),
            min: 10,
            max: 200,
            divisions: 9,
            activeColor: themeColor ?? Theme.of(context).colorScheme.primary,
            onChanged: (value) {
              searchSettingsNotifier.updateMaxResults(value.toInt());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchOption(
    BuildContext context,
    String title,
    bool value,
    VoidCallback onChanged,
    Color? themeColor,
  ) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Switch(
            value: value,
            onChanged: (_) => onChanged(),
            activeThumbColor: themeColor ?? Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: textScaling.scaledBodyMedium(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchContent(BuildContext context, SearchState searchState, Color? themeColor) {
    return switch (searchState) {
      SearchStateInitial() => _buildSearchSuggestions(context, themeColor),
      SearchStateLoading() => _buildLoadingContent(context, searchState.query!, themeColor),
      SearchStateSuccess() => _buildSearchResults(context, searchState.query!, searchState.results, themeColor),
      SearchStateError() => _buildErrorContent(context, searchState.query!, searchState.error, themeColor),
    };
  }

  Widget _buildSearchSuggestions(BuildContext context, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    final suggestions = ref.watch(searchSuggestionsProvider);
    final recentSearches = ref.watch(recentSearchesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent searches
          if (recentSearches.isNotEmpty) ...[
            Text(
              'Recent Searches',
              style: textScaling.scaledTitleMedium(context).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recentSearches.map((search) => GestureDetector(
                onTap: () => _searchFromSuggestion(search),
                child: Chip(
                  label: Text(search),
                  backgroundColor: Colors.grey.shade100,
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    ref.read(searchHistoryProvider.notifier).removeSearch(search);
                  },
                ),
              )).toList(),
            ),
            const SizedBox(height: 24),
          ],
          
          // Popular suggestions
          Text(
            'Popular Search Terms',
            style: textScaling.scaledTitleMedium(context).copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((suggestion) => GestureDetector(
              onTap: () => _searchFromSuggestion(suggestion),
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
          
          // Search tips
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
            '• Use advanced options for precise results',
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

  Widget _buildLoadingContent(BuildContext context, String query, Color? themeColor) {
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
            'Searching for "$query"...',
            style: textScaling.scaledBodyLarge(context).copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, String query, List<SearchResult> results, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);

    if (results.isEmpty) {
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
                'Try different search terms or adjust your search options.',
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
      itemCount: results.length + 1, // +1 for results header
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Found ${results.length} result${results.length == 1 ? '' : 's'} for "$query"',
              style: textScaling.scaledTitleMedium(context).copyWith(
                fontWeight: FontWeight.bold,
                color: themeColor?.withValues(alpha: 0.8) ?? 
                       Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }

        final result = results[index - 1];
        return _buildSearchResultCard(context, result, query, themeColor);
      },
    );
  }

  Widget _buildErrorContent(BuildContext context, String query, Object error, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: textScaling.scaleFactor * 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Search Error',
              style: textScaling.scaledTitleLarge(context).copyWith(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Failed to search for "$query". Please try again.',
              style: textScaling.scaledBodyMedium(context).copyWith(
                color: Colors.red.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _performSearch(),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultCard(BuildContext context, SearchResult result, String query, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToChapter(result.reference.book, result.reference.chapter, result.reference.startVerse),
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
                        result.reference.displayText,
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
                
                // Verse Text with highlighting
                RichText(
                  text: _buildHighlightedText(result.verse.text, query, context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextSpan _buildHighlightedText(String text, String query, BuildContext context) {
    final textScaling = ref.watch(textScaleProvider);
    final themeColor = Theme.of(context).colorScheme.primary;
    
    if (query.isEmpty) {
      return TextSpan(
        text: text,
        style: textScaling.scaledBodyLarge(context).copyWith(height: 1.6),
      );
    }

    final List<TextSpan> spans = [];
    final String lowerText = text.toLowerCase();
    final String lowerQuery = query.toLowerCase();
    
    int start = 0;
    int index = lowerText.indexOf(lowerQuery);
    
    while (index != -1) {
      // Add text before the match
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: textScaling.scaledBodyLarge(context).copyWith(height: 1.6),
        ));
      }
      
      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: textScaling.scaledBodyLarge(context).copyWith(
          height: 1.6,
          backgroundColor: themeColor.withValues(alpha: 0.2),
          fontWeight: FontWeight.bold,
        ),
      ));
      
      start = index + query.length;
      index = lowerText.indexOf(lowerQuery, start);
    }
    
    // Add remaining text
    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: textScaling.scaledBodyLarge(context).copyWith(height: 1.6),
      ));
    }
    
    return TextSpan(children: spans);
  }

  void _navigateToChapter(String book, int chapter, int? verse) {
    final route = '/chapter/${Uri.encodeComponent(book)}/$chapter';
    if (verse != null) {
      context.push('$route?startVerse=$verse');
    } else {
      context.push(route);
    }
  }
}
