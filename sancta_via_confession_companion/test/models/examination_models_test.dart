import 'package:flutter_test/flutter_test.dart';

import 'package:confession_companion/features/examination/data/examinations.dart';
import 'package:confession_companion/features/examination/models/examination_model.dart';
import 'package:confession_companion/features/examination/models/examination_session_model.dart';
import 'package:confession_companion/features/examination/models/examination_response_status.dart';
import 'package:confession_companion/features/examination/models/user_preferences_model.dart';

void main() {
  group('sample examination data', () {
    test('every bundled examination is complete and internally consistent', () {
      for (final examination in sampleExaminations) {
        expect(examination.id, isNotEmpty, reason: '${examination.title}');
        expect(examination.title, isNotEmpty);
        expect(examination.description, isNotEmpty);
        expect(examination.source, isNotEmpty);
        expect(examination.targetAudience, isNotEmpty);
        expect(examination.totalItems, greaterThan(0));
        expect(examination.categories, isNotEmpty);
      }
    });

    test('examination ids are unique (router navigation keys on them)', () {
      final ids = sampleExaminations.map((e) => e.id).toSet();
      expect(ids.length, sampleExaminations.length);
    });
  });

  group('ExaminationSession', () {
    test('session round-trips through JSON without losing responses', () {
      final session = ExaminationSession(examinationId: 'daily')
        ..itemResponses['item_1'] = ExaminationResponseStatus.noIssue
        ..itemResponses['item_2'] = ExaminationResponseStatus.needConfess
        ..notes['item_1'] = 'remember this'
        ..currentCategoryId = 'cat_a'
        ..currentItemId = 'item_2';

      final restored = ExaminationSession.fromJson(
        (session.toJson() as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, v),
        ),
      );

      expect(restored.examinationId, 'daily');
      expect(restored.id, session.id);
      expect(restored.itemResponses['item_1'], ExaminationResponseStatus.noIssue);
      expect(restored.itemResponses['item_2'], ExaminationResponseStatus.needConfess);
      expect(restored.notes['item_1'], 'remember this');
      expect(restored.currentCategoryId, 'cat_a');
      expect(restored.currentItemId, 'item_2');
      expect(restored.isCompleted, isFalse);
    });

    test('a fresh session has unique ids and no progress', () {
      final a = ExaminationSession(examinationId: 'daily');
      final b = ExaminationSession(examinationId: 'daily');

      expect(a.id, isNot(equals(b.id)));
      expect(a.itemResponses, isEmpty);
      expect(a.getProgress(_examinationWith(items: 10)), 0.0);
    });
  });

  group('ExaminationPreferences', () {
    test('preferences round-trip through persistence JSON', () {
      final prefs = ExaminationPreferences(
        favoriteExaminationIds: const ['daily'],
      );

      final json = prefs.toJson();
      final restored = ExaminationPreferences.fromJson(
        Map<String, dynamic>.from(json as Map<dynamic, dynamic>),
      );

      expect(restored.favoriteExaminationIds, contains('daily'));
    });
  });
}

/// Minimal stub: examination models are only used for progress maths here.
ExaminationModel _examinationWith({required int items}) {
  return sampleExaminations.firstWhere(
    (e) => e.totalItems >= items,
    orElse: () => sampleExaminations.first,
  );
}
