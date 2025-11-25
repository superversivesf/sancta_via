import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import '../../providers/prayer_providers.dart';
import '../../widgets/prayer_card.dart';
import '../prayer/prayer_detail_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showSuggestions = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    ref.read(searchQueryProvider.notifier).state = query;
    setState(() {
      _showSuggestions = query.isEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(searchQueryProvider);
    final searchResultsAsync = ref.watch(searchResultsProvider);
    final availableTags = ref.watch(availableTagsProvider);

    // Get liturgical color for theming
    final currentColor = ref.watch(currentLiturgicalColorProvider);
    final colorIntensity = ref.watch(colorIntensityProvider);
    final liturgicalColor = currentColor != null
        ? LiturgicalColor.fromString(currentColor)
        : null;
    final themeColor = liturgicalColor?.toFlutterColor(colorIntensity);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Prayers'),
        backgroundColor: themeColor?.withValues(alpha: 0.1),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search prayers by title, description, or tags...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color:
                        themeColor?.withValues(alpha: 0.3) ??
                        Theme.of(context).colorScheme.outline,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: themeColor ?? Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                fillColor: Theme.of(context).colorScheme.surface,
                filled: true,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (query) {
                ref.read(searchQueryProvider.notifier).state = query.trim();
              },
            ),
          ),
        ),
      ),
      body: _showSuggestions
          ? _buildSuggestions(context, availableTags, themeColor)
          : _buildSearchResults(context, searchResultsAsync, themeColor),
    );
  }

  Widget _buildSuggestions(
    BuildContext context,
    List<String> availableTags,
    Color? themeColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search Suggestions',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: themeColor,
            ),
          ),
          const SizedBox(height: 16),

          // Popular searches
          _buildSuggestionSection(context, 'Popular Searches', [
            'Our Father',
            'Hail Mary',
            'Morning Prayer',
            'Evening Prayer',
            'Guardian Angel',
            'St. Michael',
          ], themeColor),

          const SizedBox(height: 24),

          // Prayer tags
          _buildSuggestionSection(
            context,
            'Browse by Tags',
            availableTags.take(12).toList(),
            themeColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionSection(
    BuildContext context,
    String title,
    List<String> suggestions,
    Color? themeColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: themeColor?.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions.map((suggestion) {
            return ActionChip(
              label: Text(suggestion),
              onPressed: () {
                _searchController.text = suggestion;
                ref.read(searchQueryProvider.notifier).state = suggestion;
                setState(() {
                  _showSuggestions = false;
                });
              },
              backgroundColor: themeColor?.withValues(alpha: 0.1),
              side: themeColor != null
                  ? BorderSide(
                      color: themeColor.withValues(alpha: 0.3),
                      width: 1,
                    )
                  : null,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSearchResults(
    BuildContext context,
    AsyncValue searchResultsAsync,
    Color? themeColor,
  ) {
    return searchResultsAsync.when(
      data: (prayers) {
        if (prayers.isEmpty) {
          return _buildNoResults(context, themeColor);
        }

        return Column(
          children: [
            // Results header
            Container(
              padding: const EdgeInsets.all(16),
              color: themeColor?.withValues(alpha: 0.05),
              child: Row(
                children: [
                  Text(
                    '${prayers.length} result${prayers.length == 1 ? '' : 's'} found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: themeColor?.withValues(alpha: 0.8),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: () => _showFilterDialog(context),
                    iconSize: 20,
                  ),
                ],
              ),
            ),

            // Results list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: prayers.length,
                itemBuilder: (context, index) {
                  final prayer = prayers[index];
                  return PrayerCard(
                    prayer: prayer,
                    onTap: () => _navigateToPrayer(context, prayer.id),
                    themeColor: themeColor,
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Search Error',
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
    );
  }

  Widget _buildNoResults(BuildContext context, Color? themeColor) {
    final searchQuery = ref.watch(searchQueryProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color:
                  themeColor?.withValues(alpha: 0.6) ??
                  Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No prayers found',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'No results for "$searchQuery"',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Try searching for:\n• Prayer titles or keywords\n• Saints or feast days\n• Prayer types or occasions',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                ref.read(searchQueryProvider.notifier).state = '';
                setState(() {
                  _showSuggestions = true;
                });
              },
              child: const Text('Clear Search'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    // Similar to the filter dialog in prayer list screen
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Search filters coming soon')));
  }

  void _navigateToPrayer(BuildContext context, String prayerId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PrayerDetailScreen(prayerId: prayerId),
      ),
    );
  }
}
