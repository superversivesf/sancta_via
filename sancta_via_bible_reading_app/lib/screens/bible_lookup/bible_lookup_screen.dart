import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:bible_data/bible_data.dart';
import 'package:bible_data_riverpod/bible_data_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/app_providers.dart';
import '../../providers/book_provider.dart';
import '../../providers/text_scaling_provider.dart';

class BibleLookupScreen extends ConsumerStatefulWidget {
  const BibleLookupScreen({super.key});

  @override
  ConsumerState<BibleLookupScreen> createState() => _BibleLookupScreenState();
}

class _BibleLookupScreenState extends ConsumerState<BibleLookupScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Bible book organization
  final Map<String, List<String>> bibleBooks = {
    'Law': ['Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy'],
    'History': ['Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings', '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Tobit', 'Judith', 'Esther', '1 Maccabees', '2 Maccabees'],
    'Wisdom': ['Job', 'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon', 'Wisdom', 'Sirach'],
    'Major Prophets': ['Isaiah', 'Jeremiah', 'Lamentations', 'Baruch', 'Ezekiel', 'Daniel'],
    'Minor Prophets': ['Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi'],
  };

  final Map<String, List<String>> newTestamentBooks = {
    'Gospels': ['Matthew', 'Mark', 'Luke', 'John'],
    'History': ['Acts'],
    'Paul\'s Letters': ['Romans', '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians', 'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians', '1 Timothy', '2 Timothy', 'Titus', 'Philemon'],
    'General Letters': ['Hebrews', 'James', '1 Peter', '2 Peter', '1 John', '2 John', '3 John', 'Jude'],
    'Prophecy': ['Revelation of John'],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<String> get filteredBooks {
    final allBooks = [...bibleBooks.values.expand((books) => books), ...newTestamentBooks.values.expand((books) => books)];
    if (_searchQuery.isEmpty) return allBooks;
    return allBooks.where((book) => book.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
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
          'Bible Explorer',
          style: textScaling.scaledTitleLarge(context),
        ),
        backgroundColor: themeColor?.withValues(alpha: 0.1),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              // Translation and Search Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Translation Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.3),
                        ),
                      ),
                      child: DropdownButton<BibleTranslation>(
                        value: selectedTranslation,
                        underline: Container(),
                        isDense: true,
                        onChanged: (BibleTranslation? newValue) {
                          if (newValue != null) {
                            ref.read(appSettingsNotifierProvider).setBibleTranslation(newValue);
                          }
                        },
                        items: BibleTranslation.values.map((translation) {
                          return DropdownMenuItem(
                            value: translation,
                            child: Text(
                              translation.abbreviation,
                              style: textScaling.scaledBodySmall(context),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Search Bar
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search books...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              
              // Tabs
              TabBar(
                controller: _tabController,
                labelColor: themeColor ?? Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                indicatorColor: themeColor ?? Theme.of(context).colorScheme.primary,
                tabs: const [
                  Tab(text: 'Old Testament'),
                  Tab(text: 'New Testament'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        top: false, // Let AppBar handle top
        child: _searchQuery.isNotEmpty ? _buildSearchResults(themeColor) : _buildTabView(themeColor),
      ),
    );
  }

  Widget _buildSearchResults(Color? themeColor) {
    final filtered = filteredBooks;
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final book = filtered[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.1),
              child: Text(
                book[0],
                style: TextStyle(
                  color: themeColor ?? Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(book),
            subtitle: BookChapterCount(bookName: book),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _navigateToChapterSelection(book);
            },
          ),
        );
      },
    );
  }

  Widget _buildTabView(Color? themeColor) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildTestamentView(bibleBooks, themeColor),
        _buildTestamentView(newTestamentBooks, themeColor),
      ],
    );
  }

  Widget _buildTestamentView(Map<String, List<String>> books, Color? themeColor) {
    final textScaling = ref.watch(textScaleProvider);
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: books.keys.length,
      itemBuilder: (context, index) {
        final category = books.keys.elementAt(index);
        final categoryBooks = books[category]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                category,
                style: textScaling.scaledTitleMedium(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: themeColor?.withValues(alpha: 0.8) ?? Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3.2, // Increased aspect ratio to make cards shorter
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: categoryBooks.length,
              itemBuilder: (context, bookIndex) {
                final book = categoryBooks[bookIndex];
                
                return Card(
                  elevation: 2,
                  child: InkWell(
                    onTap: () {
                      _navigateToChapterSelection(book);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (themeColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // Reduced padding
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min, // Added to prevent overflow
                          children: [
                            Flexible( // Made flexible to prevent overflow
                              child: Text(
                                book,
                                style: textScaling.scaledBodyMedium(context).copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13, // Slightly smaller text
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2, // Allow 2 lines for longer names
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 2), // Reduced spacing
                            Flexible( // Made flexible to prevent overflow
                              child: BookChapterCount(
                                bookName: book,
                                textStyle: textScaling.scaledBodySmall(context).copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  fontSize: 11, // Smaller info text
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  void _navigateToChapterSelection(String bookName) {
    context.push('/chapter-selection/${Uri.encodeComponent(bookName)}');
  }
}

/// Widget to display chapter count for a specific book
class BookChapterCount extends ConsumerWidget {
  final String bookName;
  final TextStyle? textStyle;

  const BookChapterCount({
    required this.bookName,
    super.key,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTranslation = ref.watch(appSelectedBibleTranslationProvider);
    final chapterCountAsync = ref.watch(chapterCountProvider((
      bookName: bookName,
      translation: selectedTranslation,
    )));

    return chapterCountAsync.when(
      data: (count) => Text(
        count == 1 ? '1 chapter' : '$count chapters',
        style: textStyle,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      loading: () => SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            textStyle?.color?.withValues(alpha: 0.6) ?? 
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
      error: (error, stackTrace) => Text(
        'Bible book',
        style: textStyle,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
