import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bible_reading_app/providers/onboarding_provider.dart';

void main() {
  group('OnboardingService', () {
    setUp(() {
      // Mock shared preferences
      SharedPreferences.setMockInitialValues({});
    });

    test('should detect first run correctly', () async {
      // Should be first run initially
      expect(await OnboardingService.isFirstRun(), true);
      
      // Mark as completed
      await OnboardingService.markOnboardingCompleted();
      
      // Should no longer be first run
      expect(await OnboardingService.isFirstRun(), false);
    });

    test('should handle database initialization state', () async {
      // Should not be initialized initially
      expect(await OnboardingService.isDatabaseInitialized(), false);
      
      // Mark as completed (which also marks DB as initialized)
      await OnboardingService.markOnboardingCompleted();
      
      // Should be initialized now
      expect(await OnboardingService.isDatabaseInitialized(), true);
    });

    test('should get available bible translations', () async {
      final translations = await OnboardingService.getAvailableBibleTranslations();
      
      expect(translations.length, 3);
      expect(translations.map((t) => t.id).toList(), 
             contains('cpdv'));
      expect(translations.map((t) => t.id).toList(), 
             contains('drc'));
      expect(translations.map((t) => t.id).toList(), 
             contains('engwebc'));
    });
  });
}
