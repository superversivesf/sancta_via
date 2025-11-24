import 'package:flutter_test/flutter_test.dart';
import 'package:bible_reading_app/models/reading_plan.dart';

void main() {
  group('General Epistles Reading Plan', () {
    test('should have correct display name', () {
      expect(BookCollection.generalEpistles.displayName, 'General Epistles');
    });

    test('should have correct description', () {
      expect(
        BookCollection.generalEpistles.description,
        'Non-Pauline letters: Hebrews, James, Peter, John, and Jude',
      );
    });

    test('should contain exactly eight books', () {
      final books = BookCollection.generalEpistles.bookNames;
      expect(books.length, 8);
    });

    test('should contain the correct general epistles books in order', () {
      final books = BookCollection.generalEpistles.bookNames;
      expect(books, [
        'Hebrews', 'James', '1 Peter', '2 Peter', 
        '1 John', '2 John', '3 John', 'Jude'
      ]);
    });

    test('should include all traditional Catholic/General epistles', () {
      final books = BookCollection.generalEpistles.bookNames;
      
      // Verify it includes the key general epistles
      expect(books.contains('Hebrews'), true);
      expect(books.contains('James'), true);
      expect(books.contains('1 Peter'), true);
      expect(books.contains('2 Peter'), true);
      expect(books.contains('1 John'), true);
      expect(books.contains('2 John'), true);
      expect(books.contains('3 John'), true);
      expect(books.contains('Jude'), true);
    });

    test('should not include any Pauline epistles', () {
      final generalBooks = BookCollection.generalEpistles.bookNames;
      final paulineBooks = BookCollection.paulineEpistles.bookNames;
      
      // Ensure no overlap with Pauline epistles
      for (final book in generalBooks) {
        expect(paulineBooks.contains(book), false, 
               reason: '$book should not be in both general and Pauline epistles');
      }
    });

    test('should be able to create a reading plan with general epistles', () {
      final plan = ReadingPlan(
        id: 'test-general-epistles-plan',
        name: 'General Epistles Study',
        collection: BookCollection.generalEpistles,
        progress: ReadingProgress.start(BookCollection.generalEpistles),
        createdAt: DateTime.now(),
      );

      expect(plan.collection, BookCollection.generalEpistles);
      expect(plan.progress.currentBook, 'Hebrews');
      expect(plan.progress.currentChapter, 1);
      expect(plan.progress.books.length, 8);
    });

    test('should serialize and deserialize correctly', () {
      final originalPlan = ReadingPlan(
        id: 'test-general-epistles-plan',
        name: 'Non-Pauline Letters Study',
        collection: BookCollection.generalEpistles,
        progress: ReadingProgress.start(BookCollection.generalEpistles),
        createdAt: DateTime.now(),
      );

      // Serialize to JSON
      final json = originalPlan.toJson();
      
      // Deserialize from JSON
      final restoredPlan = ReadingPlan.fromJson(json);

      // Verify the restored plan matches the original
      expect(restoredPlan.id, originalPlan.id);
      expect(restoredPlan.name, originalPlan.name);
      expect(restoredPlan.collection, BookCollection.generalEpistles);
      expect(restoredPlan.isActive, true);
      expect(restoredPlan.progress.books, [
        'Hebrews', 'James', '1 Peter', '2 Peter', 
        '1 John', '2 John', '3 John', 'Jude'
      ]);
    });

    test('should complement pastoral epistles for complete non-Pauline NT study', () {
      final generalBooks = BookCollection.generalEpistles.bookNames;
      final pastoralBooks = BookCollection.pastoralEpistles.bookNames;
      
      // General epistles should be distinct from pastoral epistles
      final commonBooks = generalBooks.where((book) => pastoralBooks.contains(book));
      expect(commonBooks.isEmpty, true, 
             reason: 'General and pastoral epistles should not overlap');
      
      // Together they should provide comprehensive non-Pauline + pastoral coverage
      expect(generalBooks.length + pastoralBooks.length, 11); // 8 + 3 = 11 total
    });
  });
}
