import 'package:flutter_test/flutter_test.dart';
import 'package:confession_companion/features/examination/data/examinations.dart';

void main() {
  test('Sample examinations data is accessible', () {
    expect(sampleExaminations, isNotEmpty);
    expect(sampleExaminations.first.title, isNotEmpty);
    expect(sampleExaminations.first.categories, isNotEmpty);
  });

  test('Examination model structure is correct', () {
    final examination = sampleExaminations.first;
    expect(examination.id, isNotEmpty);
    expect(examination.title, isNotEmpty);
    expect(examination.description, isNotEmpty);
    expect(examination.source, isNotEmpty);
    expect(examination.targetAudience, isNotEmpty);
    expect(examination.totalItems, greaterThan(0));
  });
}
