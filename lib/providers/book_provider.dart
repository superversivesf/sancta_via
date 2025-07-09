import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bible_data_riverpod/bible_data_riverpod.dart';

/// Provider for getting available books from the actual Bible data
final availableBooksProvider = FutureProvider<List<String>>((ref) async {
  final serviceAsync = ref.watch(bibleServiceNotifierProvider);
  final selectedTranslation = ref.watch(selectedBibleTranslationProvider);
  
  return serviceAsync.when(
    data: (service) async {
      try {
        // Get the actual book names from the Bible data
        final bookNames = await service.getBookNames(selectedTranslation);
        return bookNames;
      } catch (e) {
        // Fallback to empty list if there's an error
        return <String>[];
      }
    },
    loading: () => <String>[],
    error: (error, stack) => <String>[],
  );
});

/// Provider for getting chapter count for a specific book from actual Bible data
final chapterCountProvider = FutureProvider.family<int, ({String bookName, BibleTranslation translation})>((ref, params) async {
  final serviceAsync = ref.watch(bibleServiceNotifierProvider);
  
  return serviceAsync.when(
    data: (service) async {
      try {
        // Get the Bible for the translation
        final bible = await service.getBible(params.translation);
        final book = bible.findBook(params.bookName);
        return book?.chapters.length ?? 1;
      } catch (e) {
        return 1; // Default fallback
      }
    },
    loading: () => throw Exception('Bible service is loading'),
    error: (error, stack) => throw error,
  );
});

/// Provider for checking if a book exists in the current translation
final bookExistsProvider = FutureProvider.family<bool, ({String bookName, BibleTranslation translation})>((ref, params) async {
  final serviceAsync = ref.watch(bibleServiceNotifierProvider);
  
  return serviceAsync.when(
    data: (service) async {
      try {
        return await service.hasBook(params.bookName, params.translation);
      } catch (e) {
        return false;
      }
    },
    loading: () => false,
    error: (error, stack) => false,
  );
});

/// Provider for all books organized by testament (when we have the data)
final booksByTestamentProvider = FutureProvider<Map<String, List<String>>>((ref) async {
  final availableBooks = await ref.watch(availableBooksProvider.future);
  
  // This is a simplified categorization - in reality you'd need more sophisticated logic
  // to determine Old vs New Testament from the actual Bible data
  final oldTestamentBooks = <String>[];
  final newTestamentBooks = <String>[];
  
  for (final book in availableBooks) {
    // Simple heuristic: NT books typically start after "Malachi"
    // This is approximate and should be improved with actual metadata
    if (_isNewTestamentBook(book)) {
      newTestamentBooks.add(book);
    } else {
      oldTestamentBooks.add(book);
    }
  }
  
  return {
    'Old Testament': oldTestamentBooks,
    'New Testament': newTestamentBooks,
  };
});

/// Helper function to determine if a book is likely New Testament
/// This is a simplified heuristic - in a full implementation you'd use metadata
bool _isNewTestamentBook(String bookName) {
  const newTestamentBooks = {
    'Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans',
    '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
    'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
    '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews',
    'James', '1 Peter', '2 Peter', '1 John', '2 John', '3 John',
    'Jude', 'Revelation', 'Apocalypse'
  };
  
  return newTestamentBooks.contains(bookName);
}
