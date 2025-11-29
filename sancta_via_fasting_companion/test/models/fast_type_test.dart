import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_fasting_companion/models/fast_type.dart';
import 'package:sancta_via_fasting_companion/models/fast_type_category.dart';

void main() {
  group('FastType', () {
    test('should create with required fields', () {
      final fastType = FastType(
        id: 'fast1',
        name: '16:8 Intermittent',
        description: 'Fast for 16 hours, eat for 8',
        category: FastTypeCategory.intermittent,
      );

      expect(fastType.id, 'fast1');
      expect(fastType.name, '16:8 Intermittent');
      expect(fastType.description, 'Fast for 16 hours, eat for 8');
      expect(fastType.category, FastTypeCategory.intermittent);
      expect(fastType.targetDurationHours, isNull);
      expect(fastType.milestoneMessages, isEmpty);
      expect(fastType.associatedPrayers, isEmpty);
    });

    test('should create with all fields', () {
      final fastType = FastType(
        id: 'fast2',
        name: '24-Hour Fast',
        description: 'Complete 24-hour fast',
        category: FastTypeCategory.daily24hr,
        targetDurationHours: 24,
        milestoneMessages: {
          6: 'Quarter way!',
          12: 'Halfway there!',
          18: 'Three quarters!',
        },
        associatedPrayers: ['prayer1', 'prayer2'],
      );

      expect(fastType.id, 'fast2');
      expect(fastType.targetDurationHours, 24);
      expect(fastType.milestoneMessages.length, 3);
      expect(fastType.milestoneMessages[12], 'Halfway there!');
      expect(fastType.associatedPrayers, ['prayer1', 'prayer2']);
    });

    test('toJson should serialize correctly', () {
      final fastType = FastType(
        id: 'fast3',
        name: 'Lenten Fast',
        description: 'Traditional Lenten fasting',
        category: FastTypeCategory.liturgical,
        targetDurationHours: 48,
        milestoneMessages: {
          24: 'First day complete!',
        },
        associatedPrayers: ['rosary'],
      );

      final json = fastType.toJson();

      expect(json['id'], 'fast3');
      expect(json['name'], 'Lenten Fast');
      expect(json['description'], 'Traditional Lenten fasting');
      expect(json['category'], 'liturgical');
      expect(json['targetDurationHours'], 48);
      expect(json['milestoneMessages']['24'], 'First day complete!');
      expect(json['associatedPrayers'], ['rosary']);
    });

    test('fromJson should deserialize correctly', () {
      final json = {
        'id': 'fast4',
        'name': '18:6 Intermittent',
        'description': 'Fast 18, eat 6',
        'category': 'intermittent',
        'targetDurationHours': 18,
        'milestoneMessages': {
          '9': 'Halfway!',
          '18': 'Complete!',
        },
        'associatedPrayers': ['morning_prayer'],
      };

      final fastType = FastType.fromJson(json);

      expect(fastType.id, 'fast4');
      expect(fastType.name, '18:6 Intermittent');
      expect(fastType.category, FastTypeCategory.intermittent);
      expect(fastType.targetDurationHours, 18);
      expect(fastType.milestoneMessages[9], 'Halfway!');
      expect(fastType.milestoneMessages[18], 'Complete!');
      expect(fastType.associatedPrayers, ['morning_prayer']);
    });

    test('fromJson should handle null optional fields', () {
      final json = {
        'id': 'fast5',
        'name': 'Multi-day',
        'description': 'Extended fast',
        'category': 'multiDay',
        'targetDurationHours': null,
        'milestoneMessages': null,
        'associatedPrayers': null,
      };

      final fastType = FastType.fromJson(json);

      expect(fastType.targetDurationHours, isNull);
      expect(fastType.milestoneMessages, isEmpty);
      expect(fastType.associatedPrayers, isEmpty);
    });

    test('fromJson should handle empty collections', () {
      final json = {
        'id': 'fast6',
        'name': 'Simple Fast',
        'description': 'Basic fast',
        'category': 'daily24hr',
        'targetDurationHours': 24,
        'milestoneMessages': {},
        'associatedPrayers': [],
      };

      final fastType = FastType.fromJson(json);

      expect(fastType.milestoneMessages, isEmpty);
      expect(fastType.associatedPrayers, isEmpty);
    });

    test('should roundtrip through JSON', () {
      final original = FastType(
        id: 'fast7',
        name: 'Custom Fast',
        description: 'Custom fasting protocol',
        category: FastTypeCategory.intermittent,
        targetDurationHours: 20,
        milestoneMessages: {
          5: 'Early milestone',
          10: 'Mid milestone',
          15: 'Late milestone',
        },
        associatedPrayers: ['prayer_a', 'prayer_b', 'prayer_c'],
      );

      final json = original.toJson();
      final roundtripped = FastType.fromJson(json);

      expect(roundtripped, equals(original));
    });

    test('copyWith should create modified copy', () {
      final original = FastType(
        id: 'fast8',
        name: 'Original Name',
        description: 'Original Description',
        category: FastTypeCategory.intermittent,
        targetDurationHours: 16,
      );

      final modified = original.copyWith(
        name: 'Modified Name',
        targetDurationHours: 18,
      );

      expect(modified.id, original.id);
      expect(modified.name, 'Modified Name');
      expect(modified.description, original.description);
      expect(modified.category, original.category);
      expect(modified.targetDurationHours, 18);
    });

    test('copyWith with collections should work', () {
      final original = FastType(
        id: 'fast9',
        name: 'Test',
        description: 'Test',
        category: FastTypeCategory.daily24hr,
        milestoneMessages: {1: 'One'},
        associatedPrayers: ['old'],
      );

      final modified = original.copyWith(
        milestoneMessages: {2: 'Two', 3: 'Three'},
        associatedPrayers: ['new1', 'new2'],
      );

      expect(modified.milestoneMessages, {2: 'Two', 3: 'Three'});
      expect(modified.associatedPrayers, ['new1', 'new2']);
    });

    test('equality should work correctly', () {
      final fast1 = FastType(
        id: 'fast10',
        name: 'Same Fast',
        description: 'Description',
        category: FastTypeCategory.intermittent,
        targetDurationHours: 16,
        milestoneMessages: {8: 'Half'},
        associatedPrayers: ['prayer1'],
      );

      final fast2 = FastType(
        id: 'fast10',
        name: 'Same Fast',
        description: 'Description',
        category: FastTypeCategory.intermittent,
        targetDurationHours: 16,
        milestoneMessages: {8: 'Half'},
        associatedPrayers: ['prayer1'],
      );

      final fast3 = FastType(
        id: 'fast11',
        name: 'Different Fast',
        description: 'Description',
        category: FastTypeCategory.intermittent,
        targetDurationHours: 16,
        milestoneMessages: {8: 'Half'},
        associatedPrayers: ['prayer1'],
      );

      expect(fast1, equals(fast2));
      expect(fast1, isNot(equals(fast3)));
    });

    test('equality should check milestoneMessages content', () {
      final fast1 = FastType(
        id: 'fast12',
        name: 'Test',
        description: 'Test',
        category: FastTypeCategory.daily24hr,
        milestoneMessages: {1: 'One', 2: 'Two'},
      );

      final fast2 = FastType(
        id: 'fast12',
        name: 'Test',
        description: 'Test',
        category: FastTypeCategory.daily24hr,
        milestoneMessages: {1: 'One', 2: 'Two'},
      );

      final fast3 = FastType(
        id: 'fast12',
        name: 'Test',
        description: 'Test',
        category: FastTypeCategory.daily24hr,
        milestoneMessages: {1: 'One', 2: 'Different'},
      );

      expect(fast1, equals(fast2));
      expect(fast1, isNot(equals(fast3)));
    });

    test('equality should check associatedPrayers content', () {
      final fast1 = FastType(
        id: 'fast13',
        name: 'Test',
        description: 'Test',
        category: FastTypeCategory.liturgical,
        associatedPrayers: ['a', 'b'],
      );

      final fast2 = FastType(
        id: 'fast13',
        name: 'Test',
        description: 'Test',
        category: FastTypeCategory.liturgical,
        associatedPrayers: ['a', 'b'],
      );

      final fast3 = FastType(
        id: 'fast13',
        name: 'Test',
        description: 'Test',
        category: FastTypeCategory.liturgical,
        associatedPrayers: ['a', 'c'],
      );

      expect(fast1, equals(fast2));
      expect(fast1, isNot(equals(fast3)));
    });

    test('hashCode should be consistent', () {
      final fast1 = FastType(
        id: 'fast14',
        name: 'Test',
        description: 'Test',
        category: FastTypeCategory.intermittent,
      );

      final fast2 = FastType(
        id: 'fast14',
        name: 'Test',
        description: 'Test',
        category: FastTypeCategory.intermittent,
      );

      expect(fast1.hashCode, equals(fast2.hashCode));
    });

    test('toString should return meaningful representation', () {
      final fastType = FastType(
        id: 'fast15',
        name: '16:8',
        description: 'Test',
        category: FastTypeCategory.intermittent,
      );

      final str = fastType.toString();

      expect(str, contains('FastType'));
      expect(str, contains('fast15'));
      expect(str, contains('16:8'));
    });
  });
}
