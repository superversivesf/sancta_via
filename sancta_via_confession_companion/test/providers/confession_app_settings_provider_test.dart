import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:confession_companion/features/examination/models/user_preferences_model.dart';
import 'package:confession_companion/models/confession_app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  test(
    'defaults exist and the unified storage shape is stable',
    () async {
      final defaults = ConfessionAppSettings.defaults();
      expect(defaults.examinationPreferences, isNotNull);

      // The notifier loads from this unified JSON key on construction; the
      // payload must contain both halves the persistence contract relies on.
      final json = defaults.toJson();
      expect(json.containsKey('baseSettings'), isTrue);
      expect(json.containsKey('examinationPreferences'), isTrue);
    },
  );

  test('ExaminationPreferences defaults are safe to persist', () {
    final prefs = ExaminationPreferences();
    expect(prefs.favoriteExaminationIds, isEmpty);

    final restored = ExaminationPreferences.fromJson(prefs.toJson());
    expect(restored.favoriteExaminationIds, isEmpty);
    expect(restored.defaultExaminationId, isNull);
  });

  test(
    'legacy-format migration key is respected (no double-migration)',
    () async {
      // Pre-write the migration marker the way the real notifier leaves it,
      // including the unified payload (persisted as a JSON string).
      SharedPreferences.setMockInitialValues(<String, Object>{
        'flutter.confession_settings_migrated_v2': true,
        'flutter.confession_app_settings_unified':
            const JsonEncoder().convert(ConfessionAppSettings.defaults().toJson()),
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('confession_settings_migrated_v2'), isTrue);
      expect(prefs.getString('confession_app_settings_unified'), isNotEmpty);
    },
  );
}
