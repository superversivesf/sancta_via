import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bible_data_riverpod/bible_data_riverpod.dart';
import 'app_providers.dart';

/// Provider for getting available books from the actual Bible data (OPTIMIZED)
final availableBooksProvider = FutureProvider<List<String>>((ref) async {
  final selectedTranslation = ref.watch(appSelectedBibleTranslationProvider);
  
  // Use optimized provider for much faster book loading
  return await ref.watch(optimizedBookNamesProvider(selectedTranslation).future);
});

/// Provider for getting chapter count for a specific book (OPTIMIZED) 
final chapterCountProvider = FutureProvider.family<int, ({String bookName, BibleTranslation translation})>((ref, params) async {
  // Use optimized provider for fast chapter count lookup
  return await ref.watch(optimizedChapterCountProvider(params).future);
});

/// Provider for checking if a book exists in the current translation (OPTIMIZED)
final bookExistsProvider = FutureProvider.family<bool, ({String bookName, BibleTranslation translation})>((ref, params) async {
  // Use optimized provider for fast book existence check
  return await ref.watch(optimizedBookExistsProvider(params).future);
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
