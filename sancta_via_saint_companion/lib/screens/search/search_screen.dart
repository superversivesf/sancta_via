import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saint_data/saint_data.dart';

import '../../providers/saint_providers.dart';
import '../../widgets/load_error_card.dart';
import '../../widgets/saint_image.dart';
import '../../widgets/section_spinner.dart';

/// The search screen (Task 14): the keyed `search_field` text drives
/// [saintSearchProvider] live — on EVERY change and on submit, no debounce
/// (brief pin) — over the `(query, selectedCategory)` family key. A
/// horizontal filter-chip row (an `all` chip plus the 10 [SaintCategory]
/// labels) feeds `selectedCategory`; results render as SaintCard-like tiles
/// carrying the match rationale badge (`Key('rationale_badge')`, text:
/// `name`/`patronage`/`bio` from [SaintSearchResult]) and navigates to
/// `/saints/<slug>` like SaintCard.
///
/// Pushed with a route `extra` string (PatronageChip and the category
/// detail need chips push `/search` with their need text; routes.dart
/// forwards `s.extra` string-only), the field is prefilled and the search
/// runs immediately on the first build — the watch below runs with the
/// controller's initial text.
///
/// State keys: `search_loading_state` (spinner), `search_error_state`
/// (LoadErrorCard), `search_empty_state` (no results — the blank-field idle
/// prompt is deliberately NOT the empty state), and `search_result_<slug>`
/// per result tile. NOTE: the provider family is keepAlive, so every
/// `(query, category)` keystroke key stays cached for the session — an
/// accepted cache-growth trade (Task-10 carry-forward ruling: interface
/// kept, no autoDispose).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({this.initialQuery, super.key});

  /// The route `extra` forwarded by the `/search` route (string-only).
  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  SaintCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String query = _controller.text.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                key: const Key('search_field'),
                controller: _controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Who do you need?',
                ),
                // Live search: every change and every submit re-runs the
                // provider watch below (no debounce — brief pin). The
                // rebuild re-watches with the new `(query, category)` key.
                onChanged: (String _) => setState(() {}),
                onSubmitted: (String _) => setState(() {}),
              ),
            ),
            _buildCategoryChips(),
            Expanded(
              child: query.isEmpty
                  ? const _SearchPrompt()
                  : _buildResults(context, query),
            ),
          ],
        ),
      ),
    );
  }

  /// The category filter chips: an `all` chip (null category) plus one chip
  /// per [SaintCategory], keyed `search_category_chip_<name|all>` so keyed
  /// lookups target exactly one chip. ChoiceChip toggle semantics: tapping
  /// the selected chip deselects it (back to all categories).
  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          for (final SaintCategory? category in <SaintCategory?>[
            null,
            ...SaintCategory.values,
          ]) ...<Widget>[
            ChoiceChip(
              key: Key('search_category_chip_${category?.name ?? 'all'}'),
              label: Text(category?.label ?? 'All'),
              selected: _selectedCategory == category,
              onSelected: (bool selected) => setState(
                () => _selectedCategory = selected ? category : null,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  /// The results body for [query]: the [saintSearchProvider] state for the
  /// `(query, selectedCategory)` key, through the shared section patterns
  /// (spinner / keyed LoadErrorCard). Empty data is the pinned no-results
  /// empty state.
  Widget _buildResults(BuildContext context, String query) {
    final (String, SaintCategory?) searchKey = (query, _selectedCategory);
    return ref
        .watch(saintSearchProvider(searchKey))
        .when(
          loading: () => const SectionSpinner(key: Key('search_loading_state')),
          error: (Object error, StackTrace stackTrace) => LoadErrorCard(
            stateKey: const Key('search_error_state'),
            onRetry: () => ref.invalidate(saintSearchProvider(searchKey)),
          ),
          data: (List<SaintSearchResult> results) {
            if (results.isEmpty) {
              return const Padding(
                key: Key('search_empty_state'),
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('No saints found.')),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: results.length,
              itemBuilder: (BuildContext context, int index) {
                final SaintSearchResult result = results[index];
                return _SearchResultCard(
                  key: Key('search_result_${result.saint.slug}'),
                  result: result,
                );
              },
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(height: 8),
            );
          },
        );
  }
}

/// A SaintCard-like list-row tile for one search hit: thumb, name, first
/// patronage line, and the rationale badge — the whole card tappable,
/// navigating to `/saints/<slug>` (same destination as SaintCard).
class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.result, super.key});

  /// The search hit to render (saint plus why it matched).
  final SaintSearchResult result;

  @override
  Widget build(BuildContext context) {
    final Saint saint = result.saint;
    final SaintPatronage? firstPatronage = saint.patronages.isNotEmpty
        ? saint.patronages.first
        : null;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/saints/${saint.slug}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              SaintImage(
                saint: saint,
                width: 56,
                height: 56,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      saint.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (firstPatronage != null)
                      Text(
                        '${firstPatronage.need} · '
                        '${firstPatronage.category.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 4),
                    // WHY this saint matched: the search resolver's tier
                    // ('name' | 'patronage' | 'bio'), per the Task-14 key
                    // contract — one badge per result tile.
                    Container(
                      key: const Key('rationale_badge'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        result.matchRationale,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSecondaryContainer,
                        ),
                      ),
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
}

/// The idle prompt for a blank field (not the no-results empty state).
class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Search the saints.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
