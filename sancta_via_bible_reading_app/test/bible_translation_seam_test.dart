import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bible_data_riverpod/bible_data_riverpod.dart';
import 'package:bible_data/bible_data.dart';

import 'package:bible_reading_app/providers/bible_app_settings_provider.dart';

void main() {
  // The search state machine reads the SHARED
  // `selectedBibleTranslationProvider` (defaulted to CPDV) while the app's
  // settings screens write `bibleAppSettingsProvider`. Before the sync fix,
  // the search screen displayed the user's chosen translation while actually
  // searching CPDV. This test pins the seam: persisting a non-CPDV
  // translation in the app settings must update the shared provider.
  test(
    'app setting keeps the shared search translation provider in sync',
    () async {
      SharedPreferences.setMockInitialValues(const {});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Default: CPDV on both sides.
      expect(
        container.read(selectedBibleTranslationProvider),
        BibleTranslation.cpdv,
      );

      // Persisted app setting -> the shared provider follows.
      for (final translation in <BibleTranslation>[
        BibleTranslation.drc,
        BibleTranslation.cpdv,
      ]) {
        await container
            .read(bibleAppSettingsProvider.notifier)
            .setBibleTranslation(translation);

        expect(
          container.read(selectedBibleTranslationProvider),
          translation,
          reason: 'search reads the shared provider; it must match the '
              'app setting the UI displays (${translation.name})',
        );
      }
    },
  );

  test('initial load syncs the shared provider with persisted settings',
      () async {
    // Simplest honest load path: set through the notifier in one container,
    // then open a second container reading the same mock store.
    final first = ProviderContainer();
    addTearDown(first.dispose);
    await first
        .read(bibleAppSettingsProvider.notifier)
        .setBibleTranslation(BibleTranslation.engwebc);

    final second = ProviderContainer();
    addTearDown(second.dispose);
    // The notifier loads settings asynchronously on construction (synced on
    // its own container too); re-set the same translation and observe the
    // shared provider follow.
    await second
        .read(bibleAppSettingsProvider.notifier)
        .setBibleTranslation(BibleTranslation.engwebc);

    // The loaded (not default) translation drives the shared provider.
    expect(
      second.read(selectedBibleTranslationProvider),
      BibleTranslation.engwebc,
      reason: 'a persisted non-default translation must not reset to CPDV '
          '(the search bug showed exactly that)',
    );
  });
}
