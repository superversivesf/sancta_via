import '../models/bible_translation.dart';
import '../models/scripture_reference.dart';
import '../utils/reference_parser.dart';
import 'optimized_sqlite_bible_loader.dart';

/// Debug logging utility
void optimizedBibleServiceDebugLog(String message, [String? tag]) {
  final timestamp = DateTime.now().toIso8601String();
  print('[$timestamp] ${tag != null ? '[$tag] ' : ''}$message');
}

/// Result of looking up scripture text (same as before)
class OptimizedScriptureContent {
  final ScriptureReference reference;
  final String text;
  final BibleTranslation translation;
  final bool found;
  final String? errorMessage;

  const OptimizedScriptureContent({
    required this.reference,
    required this.text,
    required this.translation,
    required this.found,
    this.errorMessage,
  });

  factory OptimizedScriptureContent.found({
    required ScriptureReference reference,
    required String text,
    required BibleTranslation translation,
  }) {
    return OptimizedScriptureContent(
      reference: reference,
      text: text,
      translation: translation,
      found: true,
    );
  }

  factory OptimizedScriptureContent.notFound({
    required ScriptureReference reference,
    required BibleTranslation translation,
    String? errorMessage,
  }) {
    return OptimizedScriptureContent(
      reference: reference,
      text: '',
      translation: translation,
      found: false,
      errorMessage: errorMessage,
    );
  }

  @override
  String toString() =>
      found ? text : 'Not found: ${errorMessage ?? 'Unknown error'}';
}

/// Optimized Bible service that loads chapters on demand
///
/// This provides much faster performance by:
/// - Not loading entire Bibles into memory
/// - Querying individual chapters directly from SQLite
/// - Caching recently accessed chapters only
/// - Fast app startup times
class OptimizedBibleService {
  final OptimizedSqliteBibleLoader _loader;

  OptimizedBibleService(this._loader);

  /// Get scripture content by reference (optimized - loads only the needed chapter)
  Future<OptimizedScriptureContent> getScriptureContent(
    ScriptureReference reference,
    BibleTranslation translation,
  ) async {
    optimizedBibleServiceDebugLog(
        'getScriptureContent called: ${reference.displayText} from ${translation.name}',
        'OPTIMIZED_SERVICE');

    try {
      // Check if book exists (fast database query)
      final hasBook = await _loader.hasBook(reference.book, translation);
      if (!hasBook) {
        optimizedBibleServiceDebugLog(
            'Book "${reference.book}" not found in ${translation.name}',
            'OPTIMIZED_SERVICE');
        return OptimizedScriptureContent.notFound(
          reference: reference,
          translation: translation,
          errorMessage:
              'Book "${reference.book}" not found in ${translation.abbreviation}',
        );
      }

      // Load only the specific chapter we need (fast!)
      optimizedBibleServiceDebugLog(
          'Loading chapter ${reference.chapter} from ${reference.book}',
          'OPTIMIZED_SERVICE');
      final chapter = await _loader.getChapter(
          translation, reference.book, reference.chapter);

      if (chapter == null) {
        optimizedBibleServiceDebugLog(
            'Chapter ${reference.chapter} not found in ${reference.book}',
            'OPTIMIZED_SERVICE');
        return OptimizedScriptureContent.notFound(
          reference: reference,
          translation: translation,
          errorMessage:
              'Chapter ${reference.chapter} not found in ${reference.book}',
        );
      }

      String text;

      if (reference.startVerse != null && reference.endVerse != null) {
        // Get specific verse range
        optimizedBibleServiceDebugLog(
            'Getting verse range ${reference.startVerse}-${reference.endVerse}',
            'OPTIMIZED_SERVICE');
        final verses =
            chapter.getVerseRange(reference.startVerse!, reference.endVerse!);
        if (verses.isEmpty) {
          optimizedBibleServiceDebugLog(
              'No verses found for range ${reference.startVerse}-${reference.endVerse}',
              'OPTIMIZED_SERVICE');
          return OptimizedScriptureContent.notFound(
            reference: reference,
            translation: translation,
            errorMessage:
                'Verses ${reference.startVerse}-${reference.endVerse} not found',
          );
        }

        text = verses.map((verse) => '${verse.number} ${verse.text}').join(' ');
        optimizedBibleServiceDebugLog(
            'Successfully retrieved ${verses.length} verses',
            'OPTIMIZED_SERVICE');
      } else {
        // Get entire chapter
        optimizedBibleServiceDebugLog(
            'Getting entire chapter ${reference.chapter}', 'OPTIMIZED_SERVICE');
        if (chapter.verses.isEmpty) {
          optimizedBibleServiceDebugLog(
              'Chapter ${reference.chapter} has no verses',
              'OPTIMIZED_SERVICE');
          return OptimizedScriptureContent.notFound(
            reference: reference,
            translation: translation,
            errorMessage: 'No verses available for this chapter',
          );
        }
        text = chapter.fullText;
        optimizedBibleServiceDebugLog(
            'Successfully retrieved entire chapter, text length: ${text.length}',
            'OPTIMIZED_SERVICE');
      }

      optimizedBibleServiceDebugLog(
          'Scripture content retrieved successfully for ${reference.displayText}',
          'OPTIMIZED_SERVICE');
      return OptimizedScriptureContent.found(
        reference: reference,
        text: text,
        translation: translation,
      );
    } catch (e) {
      optimizedBibleServiceDebugLog(
          'Error loading scripture ${reference.displayText}: $e',
          'OPTIMIZED_SERVICE');
      return OptimizedScriptureContent.notFound(
        reference: reference,
        translation: translation,
        errorMessage: 'Error loading scripture: ${e.toString()}',
      );
    }
  }

  /// Get scripture content by parsing a reference string
  Future<OptimizedScriptureContent> getScriptureByReference(
    String referenceText,
    BibleTranslation translation,
  ) async {
    try {
      final reference = ReferenceParser.parse(referenceText);
      return getScriptureContent(reference, translation);
    } catch (e) {
      final dummyRef = ScriptureReference(
        book: 'Unknown',
        chapter: 0,
        displayText: referenceText,
      );
      return OptimizedScriptureContent.notFound(
        reference: dummyRef,
        translation: translation,
        errorMessage: 'Could not parse reference: $referenceText',
      );
    }
  }

  /// Get verse text directly (convenience method)
  Future<String?> getVerseText(
    String bookName,
    int chapter,
    int verse,
    BibleTranslation translation,
  ) async {
    final reference = ScriptureReference.verse(bookName, chapter, verse);
    final content = await getScriptureContent(reference, translation);
    return content.found ? content.text : null;
  }

  /// Get chapter text directly (convenience method)
  Future<String?> getChapterText(
    String bookName,
    int chapter,
    BibleTranslation translation,
  ) async {
    final reference = ScriptureReference.chapter(bookName, chapter);
    final content = await getScriptureContent(reference, translation);
    return content.found ? content.text : null;
  }

  /// Check if a book exists in a translation (fast database query)
  Future<bool> hasBook(String bookName, BibleTranslation translation) async {
    try {
      return await _loader.hasBook(bookName, translation);
    } catch (e) {
      return false;
    }
  }

  /// Get all book names for a translation (fast - no content loading)
  Future<List<String>> getBookNames(BibleTranslation translation) async {
    try {
      return await _loader.getBookNames(translation);
    } catch (e) {
      return [];
    }
  }

  /// Get chapter count for a book (fast database query)
  Future<int> getChapterCount(
      String bookName, BibleTranslation translation) async {
    try {
      return await _loader.getChapterCount(translation, bookName);
    } catch (e) {
      return 0;
    }
  }

  /// Get available translations (fast - no content loading)
  Future<List<BibleTranslation>> getAvailableTranslations() async {
    optimizedBibleServiceDebugLog(
        'Getting available translations (optimized)...', 'OPTIMIZED_SERVICE');

    try {
      final translations = await _loader.getAvailableTranslations();
      optimizedBibleServiceDebugLog(
          'Available translations: ${translations.map((t) => '${t.name} (${t.id})').join(', ')}',
          'OPTIMIZED_SERVICE');
      return translations;
    } catch (e) {
      optimizedBibleServiceDebugLog(
          'Error getting available translations: $e', 'OPTIMIZED_SERVICE');
      rethrow;
    }
  }

  /// Check if a translation is available (fast)
  Future<bool> isTranslationAvailable(BibleTranslation translation) async {
    optimizedBibleServiceDebugLog(
        'Checking if ${translation.name} (${translation.id}) is available...',
        'OPTIMIZED_SERVICE');

    try {
      final available = await _loader.isTranslationAvailable(translation);
      optimizedBibleServiceDebugLog(
          '${translation.name} availability: $available', 'OPTIMIZED_SERVICE');
      return available;
    } catch (e) {
      optimizedBibleServiceDebugLog(
          'Error checking availability for ${translation.name}: $e',
          'OPTIMIZED_SERVICE');
      return false;
    }
  }

  /// Clear all caches
  void clearCache() {
    OptimizedSqliteBibleLoader.clearCache();
  }

  /// Get cache statistics
  Map<String, int> getCacheStats() {
    return OptimizedSqliteBibleLoader.getCacheStats();
  }

  /// Validate a scripture reference without loading content
  Future<bool> isValidReference(
    String referenceText,
    BibleTranslation translation,
  ) async {
    try {
      final reference = ReferenceParser.parse(referenceText);

      // Check if book exists (fast)
      if (!await hasBook(reference.book, translation)) return false;

      // Check if chapter exists (fast)
      final chapterCount = await getChapterCount(reference.book, translation);
      if (reference.chapter > chapterCount) return false;

      // For verse validation, we'd need to load the chapter, so skip for now
      // This is acceptable since most validation happens at the chapter level

      return true;
    } catch (e) {
      return false;
    }
  }
}
