import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_fasting_companion/models/fast_status.dart';

void main() {
  group('FastStatus', () {
    test('should have correct enum values', () {
      expect(FastStatus.values.length, 3);
      expect(FastStatus.values, contains(FastStatus.active));
      expect(FastStatus.values, contains(FastStatus.completed));
      expect(FastStatus.values, contains(FastStatus.broken));
    });

    test('toJson should return correct string', () {
      expect(FastStatus.active.toJson(), 'active');
      expect(FastStatus.completed.toJson(), 'completed');
      expect(FastStatus.broken.toJson(), 'broken');
    });

    test('fromJson should parse correctly', () {
      expect(FastStatus.fromJson('active'), FastStatus.active);
      expect(FastStatus.fromJson('completed'), FastStatus.completed);
      expect(FastStatus.fromJson('broken'), FastStatus.broken);
    });

    test('fromJson should default to active for invalid input', () {
      expect(FastStatus.fromJson('invalid'), FastStatus.active);
      expect(FastStatus.fromJson(''), FastStatus.active);
    });

    test('displayName should return correct values', () {
      expect(FastStatus.active.displayName, 'Active');
      expect(FastStatus.completed.displayName, 'Completed');
      expect(FastStatus.broken.displayName, 'Broken');
    });

    test('isOngoing should return true only for active', () {
      expect(FastStatus.active.isOngoing, isTrue);
      expect(FastStatus.completed.isOngoing, isFalse);
      expect(FastStatus.broken.isOngoing, isFalse);
    });

    test('isEnded should return true for completed and broken', () {
      expect(FastStatus.active.isEnded, isFalse);
      expect(FastStatus.completed.isEnded, isTrue);
      expect(FastStatus.broken.isEnded, isTrue);
    });

    test('should roundtrip through JSON', () {
      for (final status in FastStatus.values) {
        final json = status.toJson();
        final parsed = FastStatus.fromJson(json);
        expect(parsed, status);
      }
    });
  });
}
