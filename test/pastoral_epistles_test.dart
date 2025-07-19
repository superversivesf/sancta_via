import 'package:flutter_test/flutter_test.dart';
import 'package:bible_reading_app/models/reading_plan.dart';

void main() {
  group('Pastoral Epistles Reading Plan', () {
    test('should have correct display name', () {
      expect(BookCollection.pastoralEpistles.displayName, 'Pastoral Epistles');
    });

    test('should have correct description', () {
      expect(
        BookCollection.pastoralEpistles.description,
        'Paul\'s letters to pastors: 1 Timothy, 2 Timothy, and Titus',
      );
    });

    test('should contain exactly three books', () {
      final books = BookCollection.pastoralEpistles.bookNames;
      expect(books.length, 3);
    });

    test('should contain the correct pastoral epistles books in order', () {
      final books = BookCollection.pastoralEpistles.bookNames;
      expect(books, ['1 Timothy', '2 Timothy', 'Titus']);
    });

    test('should be able to create a reading plan with pastoral epistles', () {
      final plan = ReadingPlan(
        id: 'test-pastoral-plan',
        name: 'My Pastoral Epistles Plan',
        collection: BookCollection.pastoralEpistles,
        frequency: ReadingFrequency.daily,
        scheduledDays: {DayOfWeek.monday, DayOfWeek.wednesday, DayOfWeek.friday},
        chaptersPerDay: 1,
        remindersEnabled: true,
        progress: ReadingProgress.start(BookCollection.pastoralEpistles),
        createdAt: DateTime.now(),
      );

      expect(plan.collection, BookCollection.pastoralEpistles);
      expect(plan.progress.currentBook, '1 Timothy');
      expect(plan.progress.currentChapter, 1);
      expect(plan.progress.books, ['1 Timothy', '2 Timothy', 'Titus']);
    });

    test('should serialize and deserialize correctly', () {
      final originalPlan = ReadingPlan(
        id: 'test-pastoral-plan',
        name: 'Pastoral Epistles Study',
        collection: BookCollection.pastoralEpistles,
        frequency: ReadingFrequency.weekdays,
        scheduledDays: DayOfWeek.fromFrequency(ReadingFrequency.weekdays).toSet(),
        chaptersPerDay: 2,
        remindersEnabled: false,
        progress: ReadingProgress.start(BookCollection.pastoralEpistles),
        createdAt: DateTime.now(),
      );

      // Serialize to JSON
      final json = originalPlan.toJson();
      
      // Deserialize from JSON
      final restoredPlan = ReadingPlan.fromJson(json);

      // Verify the restored plan matches the original
      expect(restoredPlan.id, originalPlan.id);
      expect(restoredPlan.name, originalPlan.name);
      expect(restoredPlan.collection, BookCollection.pastoralEpistles);
      expect(restoredPlan.frequency, ReadingFrequency.weekdays);
      expect(restoredPlan.chaptersPerDay, 2);
      expect(restoredPlan.progress.books, ['1 Timothy', '2 Timothy', 'Titus']);
    });
  });
}
