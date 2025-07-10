import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';
import '../../providers/calendar_providers.dart' as local_providers;

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(local_providers.searchResultsProvider);
    final searchQuery = ref.watch(local_providers.searchQueryProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Celebrations'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search input
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search for feasts, saints, celebrations...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(local_providers.searchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: (value) {
                ref.read(local_providers.searchQueryProvider.notifier).state = value;
              },
              textInputAction: TextInputAction.search,
            ),
          ),
          
          // Search results
          Expanded(
            child: searchQuery.isEmpty
                ? _buildEmptyState(context)
                : searchResults.isEmpty
                    ? _buildNoResultsState(context, searchQuery)
                    : _buildSearchResults(context, ref, searchResults),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Search for celebrations',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Find feasts, saints, solemnities and more',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            children: [
              _buildSuggestionChip(context, 'Christmas'),
              _buildSuggestionChip(context, 'Easter'),
              _buildSuggestionChip(context, 'Mary'),
              _buildSuggestionChip(context, 'Joseph'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(BuildContext context, String suggestion) {
    return ActionChip(
      label: Text(suggestion),
      onPressed: () {
        _searchController.text = suggestion;
        ref.read(local_providers.searchQueryProvider.notifier).state = suggestion;
      },
    );
  }

  Widget _buildNoResultsState(BuildContext context, String query) {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No celebrations found for "$query"',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, WidgetRef ref, List<LiturgicalDayData> results) {
    final today = DateTime.now();
    final oneYearAhead = DateTime(today.year + 1, today.month, today.day);
    
    return Column(
      children: [
        // Info banner about the search scope
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${results.length} results through ${DateFormat('MMM d, yyyy').format(oneYearAhead)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Search results list
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index];
              return _buildSearchResultTile(context, ref, result);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultTile(BuildContext context, WidgetRef ref, LiturgicalDayData result) {
    final theme = Theme.of(context);
    final colorIntensity = ref.watch(colorIntensityProvider);
    final liturgicalColor = result.celebration.color.toLiturgicalColor(colorIntensity);
    final resultDate = DateTime.parse(result.date);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: liturgicalColor,
          child: Icon(
            _getCelebrationIcon(result),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          result.celebration.name.isEmpty 
              ? result.season 
              : result.celebration.name,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: result.celebration.rank == 'SOLEMNITY' 
                ? FontWeight.bold 
                : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('MMMM d, yyyy').format(resultDate)),
            if (result.celebration.rank != 'WEEKDAY')
              Text(
                _formatRank(result.celebration.rank),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: liturgicalColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: result.celebration.prioritized
            ? Icon(
                Icons.star,
                color: Colors.amber[700],
              )
            : null,
        onTap: () {
          context.push('/day/${resultDate.toIso8601String().split('T')[0]}');
        },
      ),
    );
  }

  IconData _getCelebrationIcon(LiturgicalDayData liturgicalDay) {
    switch (liturgicalDay.celebration.rank) {
      case 'SOLEMNITY':
        return Icons.star;
      case 'FEAST':
        return Icons.star_half;
      case 'MEMORIAL':
        return Icons.circle;
      case 'OPT_MEMORIAL':
        return Icons.circle_outlined;
      default:
        return liturgicalDay.celebration.prioritized 
            ? Icons.star_outline 
            : Icons.event;
    }
  }

  String _formatRank(String rank) {
    switch (rank.toUpperCase()) {
      case 'SOLEMNITY':
        return 'Solemnity';
      case 'FEAST':
        return 'Feast';
      case 'MEMORIAL':
        return 'Memorial';
      case 'OPT_MEMORIAL':
        return 'Optional Memorial';
      default:
        return rank;
    }
  }
}