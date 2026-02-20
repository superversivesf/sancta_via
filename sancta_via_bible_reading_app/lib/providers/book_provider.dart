import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bible_data_riverpod/bible_data_riverpod.dart';
import 'app_providers.dart';

/// Provider for getting available books from the actual Bible data (OPTIMIZED)
final availableBooksProvider = FutureProvider<List<String>>((ref) async {
  final selectedTranslation = ref.watch(appSelectedBibleTranslationProvider);

  // Use optimized provider for much faster book loading
  return await ref.watch(
    optimizedBookNamesProvider(selectedTranslation).future,
  );
});

/// Provider for getting chapter count for a specific book (OPTIMIZED)
final chapterCountProvider =
    FutureProvider.family<
      int,
      ({String bookName, BibleTranslation translation})
    >((ref, params) async {
      // Use optimized provider for fast chapter count lookup
      return await ref.watch(optimizedChapterCountProvider(params).future);
    });

/// Provider for checking if a book exists in the current translation (OPTIMIZED)
final bookExistsProvider =
    FutureProvider.family<
      bool,
      ({String bookName, BibleTranslation translation})
    >((ref, params) async {
      // Use optimized provider for fast book existence check
      return await ref.watch(optimizedBookExistsProvider(params).future);
    });

/// Provider for all books organized by testament (when we have the data)
final booksByTestamentProvider = FutureProvider<Map<String, List<String>>>((
  ref,
) async {
  final availableBooks = await ref.watch(availableBooksProvider.future);

  // Use canonical book mapping for accurate testament categorization
  final oldTestamentBooks = <String>[];
  final newTestamentBooks = <String>[];

  for (final book in availableBooks) {
    // Use the canonical BibleBookMapping for accurate categorization
    final metadata = BibleBookMapping.getByName(book);
    if (metadata != null) {
      if (metadata.isOldTestament) {
        oldTestamentBooks.add(book);
      } else {
        newTestamentBooks.add(book);
      }
    } else {
      // Fallback for unknown books: assume Old Testament
      // This handles edge cases where book names might differ slightly
      oldTestamentBooks.add(book);
    }
  }

  return {
    'Old Testament': oldTestamentBooks,
    'New Testament': newTestamentBooks,
  };
});
