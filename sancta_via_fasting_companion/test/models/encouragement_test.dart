import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_fasting_companion/models/encouragement.dart';
import 'package:sancta_via_fasting_companion/models/encouragement_category.dart';

void main() {
  group('Encouragement', () {
    test('should create with required fields', () {
      final encouragement = Encouragement(
        id: 'enc1',
        category: EncouragementCategory.scripture,
        triggerPoint: 'start',
        content: 'Blessed are those who hunger',
      );

      expect(encouragement.id, 'enc1');
      expect(encouragement.category, EncouragementCategory.scripture);
      expect(encouragement.triggerPoint, 'start');
      expect(encouragement.content, 'Blessed are those who hunger');
      expect(encouragement.liturgicalSeason, isNull);
      expect(encouragement.attribution, isNull);
      expect(encouragement.relatedScripture, isNull);
      expect(encouragement.categoryHint, isNull);
    });

    test('should create with all fields', () {
      final encouragement = Encouragement(
        id: 'enc2',
        category: EncouragementCategory.saintQuote,
        triggerPoint: 'milestone',
        liturgicalSeason: 'lent',
        content: 'Fasting cleanses the soul',
        attribution: 'St. Augustine',
        relatedScripture: 'Matthew 6:16-18',
        categoryHint: 'perseverance',
      );

      expect(encouragement.id, 'enc2');
      expect(encouragement.category, EncouragementCategory.saintQuote);
      expect(encouragement.triggerPoint, 'milestone');
      expect(encouragement.liturgicalSeason, 'lent');
      expect(encouragement.content, 'Fasting cleanses the soul');
      expect(encouragement.attribution, 'St. Augustine');
      expect(encouragement.relatedScripture, 'Matthew 6:16-18');
      expect(encouragement.categoryHint, 'perseverance');
    });

    test('toJson should serialize correctly', () {
      final encouragement = Encouragement(
        id: 'enc3',
        category: EncouragementCategory.prayer,
        triggerPoint: 'completion',
        liturgicalSeason: 'advent',
        content: 'Lord, I thank You',
        attribution: 'Traditional',
        relatedScripture: 'Psalm 100',
        categoryHint: 'thanksgiving',
      );

      final json = encouragement.toJson();

      expect(json['id'], 'enc3');
      expect(json['category'], 'prayer');
      expect(json['triggerPoint'], 'completion');
      expect(json['liturgicalSeason'], 'advent');
      expect(json['content'], 'Lord, I thank You');
      expect(json['attribution'], 'Traditional');
      expect(json['relatedScripture'], 'Psalm 100');
      expect(json['categoryHint'], 'thanksgiving');
    });

    test('fromJson should deserialize correctly', () {
      final json = {
        'id': 'enc4',
        'category': 'scripture',
        'triggerPoint': 'hourly',
        'liturgicalSeason': 'easter',
        'content': 'He is risen!',
        'attribution': 'Gospel',
        'relatedScripture': 'Luke 24:6',
        'categoryHint': 'victory',
      };

      final encouragement = Encouragement.fromJson(json);

      expect(encouragement.id, 'enc4');
      expect(encouragement.category, EncouragementCategory.scripture);
      expect(encouragement.triggerPoint, 'hourly');
      expect(encouragement.liturgicalSeason, 'easter');
      expect(encouragement.content, 'He is risen!');
      expect(encouragement.attribution, 'Gospel');
      expect(encouragement.relatedScripture, 'Luke 24:6');
      expect(encouragement.categoryHint, 'victory');
    });

    test('fromJson should handle null optional fields', () {
      final json = {
        'id': 'enc5',
        'category': 'scripture',
        'triggerPoint': 'start',
        'liturgicalSeason': null,
        'content': 'Content here',
        'attribution': null,
        'relatedScripture': null,
        'categoryHint': null,
      };

      final encouragement = Encouragement.fromJson(json);

      expect(encouragement.liturgicalSeason, isNull);
      expect(encouragement.attribution, isNull);
      expect(encouragement.relatedScripture, isNull);
      expect(encouragement.categoryHint, isNull);
    });

    test('should roundtrip through JSON', () {
      final original = Encouragement(
        id: 'enc6',
        category: EncouragementCategory.saintQuote,
        triggerPoint: 'difficulty',
        liturgicalSeason: 'ordinary',
        content: 'Persevere in faith',
        attribution: 'St. Paul',
        relatedScripture: 'Romans 5:3',
        categoryHint: 'suffering',
      );

      final json = original.toJson();
      final roundtripped = Encouragement.fromJson(json);

      expect(roundtripped, equals(original));
    });

    test('copyWith should create modified copy', () {
      final original = Encouragement(
        id: 'enc7',
        category: EncouragementCategory.scripture,
        triggerPoint: 'start',
        content: 'Original content',
      );

      final modified = original.copyWith(
        content: 'Modified content',
        attribution: 'New attribution',
      );

      expect(modified.id, original.id);
      expect(modified.category, original.category);
      expect(modified.triggerPoint, original.triggerPoint);
      expect(modified.content, 'Modified content');
      expect(modified.attribution, 'New attribution');
    });

    test('equality should work correctly', () {
      final enc1 = Encouragement(
        id: 'enc8',
        category: EncouragementCategory.prayer,
        triggerPoint: 'start',
        content: 'Content',
        attribution: 'Author',
      );

      final enc2 = Encouragement(
        id: 'enc8',
        category: EncouragementCategory.prayer,
        triggerPoint: 'start',
        content: 'Content',
        attribution: 'Author',
      );

      final enc3 = Encouragement(
        id: 'enc9',
        category: EncouragementCategory.prayer,
        triggerPoint: 'start',
        content: 'Content',
        attribution: 'Author',
      );

      expect(enc1, equals(enc2));
      expect(enc1, isNot(equals(enc3)));
    });

    test('hashCode should be consistent', () {
      final enc1 = Encouragement(
        id: 'enc10',
        category: EncouragementCategory.scripture,
        triggerPoint: 'milestone',
        content: 'Content',
      );

      final enc2 = Encouragement(
        id: 'enc10',
        category: EncouragementCategory.scripture,
        triggerPoint: 'milestone',
        content: 'Content',
      );

      expect(enc1.hashCode, equals(enc2.hashCode));
    });

    test('toString should return meaningful representation', () {
      final encouragement = Encouragement(
        id: 'enc11',
        category: EncouragementCategory.scripture,
        triggerPoint: 'start',
        content: 'Test content',
      );

      final str = encouragement.toString();

      expect(str, contains('Encouragement'));
      expect(str, contains('enc11'));
      expect(str, contains('scripture'));
    });
  });
}
