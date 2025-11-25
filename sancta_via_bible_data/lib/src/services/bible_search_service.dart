import '../models/bible.dart';
import '../models/bible_book.dart';
import '../models/bible_chapter.dart';
import '../models/bible_verse.dart';
import '../models/scripture_reference.dart';

/// Result of a Bible search
class SearchResult {
  /// The verse that matched the search
  final BibleVerse verse;

  /// The book containing the verse
  final BibleBook book;

  /// The chapter containing the verse
  final BibleChapter chapter;

  /// The scripture reference for this result
  final ScriptureReference reference;

  /// Relevance score (0.0 to 1.0)
  final double relevance;

  const SearchResult({
    required this.verse,
    required this.book,
    required this.chapter,
    required this.reference,
    required this.relevance,
  });

  /// Get formatted display text for this result
  String get displayText => '${reference.displayText} - ${verse.text}';

  @override
  String toString() => displayText;
}

/// Service for searching Bible content
class BibleSearchService {
  final Bible bible;

  const BibleSearchService(this.bible);

  /// Search for text across all books
  Future<List<SearchResult>> searchText(
    String query, {
    bool caseSensitive = false,
    bool wholeWords = false,
    List<String>? bookFilter,
    bool oldTestamentOnly = false,
    bool newTestamentOnly = false,
    int maxResults = 100,
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final results = <SearchResult>[];
    final processedQuery = caseSensitive ? query : query.toLowerCase();

    // Create word boundary regex if wholeWords is true
    final searchPattern = wholeWords
        ? RegExp(r'\b' + RegExp.escape(processedQuery) + r'\b',
            caseSensitive: caseSensitive)
        : null;

    for (final book in bible.books) {
      // Apply filters
      if (bookFilter != null &&
          !bookFilter.contains(book.id) &&
          !bookFilter.contains(book.name) &&
          !bookFilter.contains(book.abbreviation)) {
        continue;
      }

      if (oldTestamentOnly && !book.isOldTestament) continue;
      if (newTestamentOnly && book.isOldTestament) continue;

      for (final chapter in book.chapters) {
        for (final verse in chapter.verses) {
          final verseText =
              caseSensitive ? verse.text : verse.text.toLowerCase();
          bool matches = false;

          if (wholeWords && searchPattern != null) {
            matches = searchPattern.hasMatch(verse.text);
          } else {
            matches = verseText.contains(processedQuery);
          }

          if (matches) {
            final reference = ScriptureReference.verse(
                book.name, chapter.number, verse.number);

            // Calculate relevance score
            final relevance =
                _calculateRelevance(verse.text, processedQuery, caseSensitive);

            results.add(SearchResult(
              verse: verse,
              book: book,
              chapter: chapter,
              reference: reference,
              relevance: relevance,
            ));

            if (results.length >= maxResults) {
              break;
            }
          }
        }
        if (results.length >= maxResults) break;
      }
      if (results.length >= maxResults) break;
    }

    // Sort by relevance (highest first)
    results.sort((a, b) => b.relevance.compareTo(a.relevance));

    return results;
  }

  /// Search for exact phrases
  Future<List<SearchResult>> searchPhrase(
    String phrase, {
    bool caseSensitive = false,
    List<String>? bookFilter,
    int maxResults = 100,
  }) async {
    return searchText(
      phrase,
      caseSensitive: caseSensitive,
      wholeWords: false,
      bookFilter: bookFilter,
      maxResults: maxResults,
    );
  }

  /// Search for any of the given words
  Future<List<SearchResult>> searchAnyWord(
    List<String> words, {
    bool caseSensitive = false,
    List<String>? bookFilter,
    int maxResults = 100,
  }) async {
    final allResults = <SearchResult>[];
    final seenVerses = <String>{};

    for (final word in words) {
      final wordResults = await searchText(
        word,
        caseSensitive: caseSensitive,
        bookFilter: bookFilter,
        maxResults: maxResults,
      );

      for (final result in wordResults) {
        final verseKey =
            '${result.book.id}_${result.chapter.number}_${result.verse.number}';
        if (!seenVerses.contains(verseKey)) {
          seenVerses.add(verseKey);
          allResults.add(result);
        }
      }

      if (allResults.length >= maxResults) break;
    }

    // Sort by relevance
    allResults.sort((a, b) => b.relevance.compareTo(a.relevance));

    return allResults.take(maxResults).toList();
  }

  /// Search for all of the given words (must all be present)
  Future<List<SearchResult>> searchAllWords(
    List<String> words, {
    bool caseSensitive = false,
    List<String>? bookFilter,
    int maxResults = 100,
  }) async {
    if (words.isEmpty) return [];

    final results = <SearchResult>[];
    final processedWords =
        caseSensitive ? words : words.map((w) => w.toLowerCase()).toList();

    for (final book in bible.books) {
      // Apply filters
      if (bookFilter != null &&
          !bookFilter.contains(book.id) &&
          !bookFilter.contains(book.name) &&
          !bookFilter.contains(book.abbreviation)) {
        continue;
      }

      for (final chapter in book.chapters) {
        for (final verse in chapter.verses) {
          final verseText =
              caseSensitive ? verse.text : verse.text.toLowerCase();

          // Check if all words are present
          final allWordsPresent =
              processedWords.every((word) => verseText.contains(word));

          if (allWordsPresent) {
            final reference = ScriptureReference.verse(
                book.name, chapter.number, verse.number);

            // Calculate relevance based on all words
            final relevance = _calculateMultiWordRelevance(
                verse.text, processedWords, caseSensitive);

            results.add(SearchResult(
              verse: verse,
              book: book,
              chapter: chapter,
              reference: reference,
              relevance: relevance,
            ));

            if (results.length >= maxResults) break;
          }
        }
        if (results.length >= maxResults) break;
      }
      if (results.length >= maxResults) break;
    }

    // Sort by relevance
    results.sort((a, b) => b.relevance.compareTo(a.relevance));

    return results;
  }

  /// Search by verse number pattern (e.g., all verse 16s)
  Future<List<SearchResult>> searchByVerseNumber(
    int verseNumber, {
    List<String>? bookFilter,
    int maxResults = 100,
  }) async {
    final results = <SearchResult>[];

    for (final book in bible.books) {
      if (bookFilter != null &&
          !bookFilter.contains(book.id) &&
          !bookFilter.contains(book.name) &&
          !bookFilter.contains(book.abbreviation)) {
        continue;
      }

      for (final chapter in book.chapters) {
        final verse = chapter.getVerse(verseNumber);
        if (verse != null) {
          final reference =
              ScriptureReference.verse(book.name, chapter.number, verse.number);

          results.add(SearchResult(
            verse: verse,
            book: book,
            chapter: chapter,
            reference: reference,
            relevance: 1.0, // All results are equally relevant
          ));

          if (results.length >= maxResults) break;
        }
      }
      if (results.length >= maxResults) break;
    }

    return results;
  }

  /// Get verses around a specific reference (context)
  Future<List<SearchResult>> getContext(
    ScriptureReference reference, {
    int versesBefore = 2,
    int versesAfter = 2,
  }) async {
    final book = bible.findBook(reference.book);
    if (book == null) return [];

    final chapter = book.getChapter(reference.chapter);
    if (chapter == null) return [];

    final results = <SearchResult>[];
    final centerVerse = reference.startVerse ?? 1;

    final startVerse =
        (centerVerse - versesBefore).clamp(1, chapter.maxVerseNumber);
    final endVerse =
        (centerVerse + versesAfter).clamp(1, chapter.maxVerseNumber);

    for (int verseNum = startVerse; verseNum <= endVerse; verseNum++) {
      final verse = chapter.getVerse(verseNum);
      if (verse != null) {
        final verseRef =
            ScriptureReference.verse(book.name, chapter.number, verse.number);
        results.add(SearchResult(
          verse: verse,
          book: book,
          chapter: chapter,
          reference: verseRef,
          relevance: verseNum == centerVerse ? 1.0 : 0.5,
        ));
      }
    }

    return results;
  }

  /// Calculate relevance score for a single search term
  double _calculateRelevance(
      String verseText, String query, bool caseSensitive) {
    final text = caseSensitive ? verseText : verseText.toLowerCase();
    final searchTerm = caseSensitive ? query : query.toLowerCase();

    // Base score for containing the term
    double score = 0.5;

    // Bonus for exact word matches
    final words = text.split(RegExp(r'\W+'));
    if (words.any((word) => word == searchTerm)) {
      score += 0.3;
    }

    // Bonus for term appearing at the beginning
    if (text.startsWith(searchTerm)) {
      score += 0.2;
    }

    // Bonus for multiple occurrences
    final occurrences = searchTerm.allMatches(text).length;
    if (occurrences > 1) {
      score += (occurrences - 1) * 0.1;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Calculate relevance score for multiple search terms
  double _calculateMultiWordRelevance(
      String verseText, List<String> queries, bool caseSensitive) {
    double totalScore = 0.0;

    for (final query in queries) {
      totalScore += _calculateRelevance(verseText, query, caseSensitive);
    }

    // Average the scores and add bonus for having all terms
    double score = totalScore / queries.length;
    score += 0.2; // Bonus for having all terms

    return score.clamp(0.0, 1.0);
  }
}
