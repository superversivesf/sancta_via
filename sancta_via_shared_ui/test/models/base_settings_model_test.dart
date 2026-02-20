import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_shared_ui/src/models/base_settings_model.dart';

void main() {
  group('TextScalingMode', () {
    test('scaleFactor values are correct', () {
      expect(TextScalingMode.small.scaleFactor, equals(0.85));
      expect(TextScalingMode.normal.scaleFactor, equals(1.0));
      expect(TextScalingMode.large.scaleFactor, equals(1.15));
      expect(TextScalingMode.extraLarge.scaleFactor, equals(1.3));
    });

    test('displayName returns correct strings', () {
      expect(TextScalingMode.small.displayName, equals('Small'));
      expect(TextScalingMode.normal.displayName, equals('Normal'));
      expect(TextScalingMode.large.displayName, equals('Large'));
      expect(TextScalingMode.extraLarge.displayName, equals('Extra Large'));
    });
  });

  group('AppLanguage', () {
    test('displayName returns correct strings', () {
      expect(AppLanguage.english.displayName, equals('English'));
      expect(AppLanguage.latin.displayName, equals('Latin'));
      expect(AppLanguage.spanish.displayName, equals('Spanish'));
    });

    test('code returns correct ISO codes', () {
      expect(AppLanguage.english.code, equals('en'));
      expect(AppLanguage.latin.code, equals('la'));
      expect(AppLanguage.spanish.code, equals('es'));
    });
  });

  group('BaseSettingsModel', () {
    test('defaults creates model with default values', () {
      final model = BaseSettingsModel.defaults();
      expect(model.fontSize, equals(18.0));
      expect(model.textScalingMode, equals(TextScalingMode.normal));
      expect(model.defaultLanguage, equals(AppLanguage.english));
      expect(model.notificationsEnabled, isFalse);
      expect(model.showLiturgicalColors, isTrue);
      expect(model.hapticFeedbackEnabled, isTrue);
      expect(model.reduceMotion, isFalse);
    });

    test('fromJson parses valid JSON correctly', () {
      final json = {
        'fontSize': 20.0,
        'textScalingMode': 2,
        'defaultLanguage': 'la',
        'notificationsEnabled': true,
        'showLiturgicalColors': false,
        'hapticFeedbackEnabled': false,
        'reduceMotion': true,
      };
      final model = BaseSettingsModel.fromJson(json);
      expect(model.fontSize, equals(20.0));
      expect(model.textScalingMode, equals(TextScalingMode.large));
      expect(model.defaultLanguage, equals(AppLanguage.latin));
      expect(model.notificationsEnabled, isTrue);
      expect(model.showLiturgicalColors, isFalse);
      expect(model.hapticFeedbackEnabled, isFalse);
      expect(model.reduceMotion, isTrue);
    });

    test('fromJson handles missing fields with defaults', () {
      final model = BaseSettingsModel.fromJson({});
      expect(model.fontSize, equals(18.0));
      expect(model.textScalingMode, equals(TextScalingMode.normal));
      expect(model.defaultLanguage, equals(AppLanguage.english));
      expect(model.notificationsEnabled, isFalse);
    });

    test('fromJson clamps fontSize to valid range', () {
      expect(
          BaseSettingsModel.fromJson({'fontSize': 5}).fontSize, equals(12.0));
      expect(
          BaseSettingsModel.fromJson({'fontSize': 100}).fontSize, equals(32.0));
    });

    test('fromJson handles invalid textScalingMode gracefully', () {
      final model = BaseSettingsModel.fromJson({'textScalingMode': 999});
      expect(model.textScalingMode, equals(TextScalingMode.normal));
    });

    test('fromJson handles invalid language code gracefully', () {
      final model = BaseSettingsModel.fromJson({'defaultLanguage': 'invalid'});
      expect(model.defaultLanguage, equals(AppLanguage.english));
    });

    test('toJson produces correct output', () {
      final model = BaseSettingsModel(
        fontSize: 22.0,
        textScalingMode: TextScalingMode.large,
        defaultLanguage: AppLanguage.spanish,
        notificationsEnabled: true,
        showLiturgicalColors: false,
        hapticFeedbackEnabled: false,
        reduceMotion: true,
      );
      final json = model.toJson();
      expect(json['fontSize'], equals(22.0));
      expect(json['textScalingMode'], equals(2));
      expect(json['defaultLanguage'], equals('es'));
      expect(json['notificationsEnabled'], isTrue);
      expect(json['showLiturgicalColors'], isFalse);
      expect(json['hapticFeedbackEnabled'], isFalse);
      expect(json['reduceMotion'], isTrue);
    });

    test('copyWith preserves unchanged fields', () {
      final original = BaseSettingsModel(
        fontSize: 20.0,
        textScalingMode: TextScalingMode.large,
        defaultLanguage: AppLanguage.latin,
      );
      final copy = original.copyWith(fontSize: 24.0);
      expect(copy.fontSize, equals(24.0));
      expect(copy.textScalingMode, equals(TextScalingMode.large));
      expect(copy.defaultLanguage, equals(AppLanguage.latin));
    });

    test('copyWith can change all fields', () {
      final original = BaseSettingsModel.defaults();
      final copy = original.copyWith(
        fontSize: 24.0,
        textScalingMode: TextScalingMode.extraLarge,
        defaultLanguage: AppLanguage.spanish,
        notificationsEnabled: true,
        showLiturgicalColors: false,
        hapticFeedbackEnabled: false,
        reduceMotion: true,
      );
      expect(copy.fontSize, equals(24.0));
      expect(copy.textScalingMode, equals(TextScalingMode.extraLarge));
      expect(copy.defaultLanguage, equals(AppLanguage.spanish));
      expect(copy.notificationsEnabled, isTrue);
      expect(copy.showLiturgicalColors, isFalse);
      expect(copy.hapticFeedbackEnabled, isFalse);
      expect(copy.reduceMotion, isTrue);
    });

    test('effectiveTextScaleFactor combines scaling mode and font size', () {
      final model = BaseSettingsModel(
        fontSize: 18.0,
        textScalingMode: TextScalingMode.normal,
      );
      expect(model.effectiveTextScaleFactor, equals(1.0));
    });

    test('effectiveTextScaleFactor scales larger font correctly', () {
      final model = BaseSettingsModel(
        fontSize: 24.0,
        textScalingMode: TextScalingMode.large,
      );
      final expected = 1.15 * (24.0 / 18.0);
      expect(model.effectiveTextScaleFactor, closeTo(expected, 0.001));
    });

    test('fontSizeLabel returns correct labels', () {
      expect(
          BaseSettingsModel(fontSize: 10.0).fontSizeLabel, equals('Smallest'));
      expect(
          BaseSettingsModel(fontSize: 13.0).fontSizeLabel, equals('Smaller'));
      expect(BaseSettingsModel(fontSize: 15.0).fontSizeLabel, equals('Small'));
      expect(BaseSettingsModel(fontSize: 18.0).fontSizeLabel, equals('Normal'));
      expect(BaseSettingsModel(fontSize: 20.0).fontSizeLabel, equals('Large'));
      expect(BaseSettingsModel(fontSize: 22.0).fontSizeLabel, equals('Larger'));
      expect(
          BaseSettingsModel(fontSize: 28.0).fontSizeLabel, equals('Largest'));
    });

    test('equality works correctly', () {
      final a = BaseSettingsModel(fontSize: 20.0);
      final b = BaseSettingsModel(fontSize: 20.0);
      final c = BaseSettingsModel(fontSize: 22.0);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode is consistent with equality', () {
      final a = BaseSettingsModel(fontSize: 20.0);
      final b = BaseSettingsModel(fontSize: 20.0);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString contains all fields', () {
      final model = BaseSettingsModel.defaults();
      final str = model.toString();
      expect(str, contains('BaseSettingsModel'));
      expect(str, contains('fontSize'));
      expect(str, contains('textScalingMode'));
      expect(str, contains('defaultLanguage'));
    });
  });
}
