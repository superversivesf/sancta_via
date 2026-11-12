// Settings screen widget tests (Task 16).
//
// Harness (Task-15 pattern minus the database): the screen reads favorites
// and recents counts from the Task-9 saintAppSettingsProvider — synchronous
// state loaded off mock SharedPreferences — and displays the saints data
// version straight from `sancta_via_saint_data`'s `saintsSchemaVersion`
// constant. No database access at all. The mock store is seeded BEFORE the
// container is created and the settings notifier's fire-and-forget async
// load is drained inside `tester.runAsync` before pumping, so the widget
// phase renders every selector and count synchronously and `pumpAndSettle`
// is safe (SharedPreferences mocks complete via microtasks, never real
// timers). The shared-UI selectors' base-settings loads settle inside the
// fake-async widget phase the same way.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saint_companion/providers/saint_app_settings_provider.dart';
import 'package:saint_companion/screens/settings/settings_screen.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Key _appDataSectionKey = Key('app_data_section');
const Key _favoritesCountKey = Key('app_data_favorites_count');
const Key _recentsCountKey = Key('app_data_recents_count');
const Key _dataVersionKey = Key('app_data_data_version');
const Key _datasetCreditSectionKey = Key('dataset_credit_section');
const Key _datasetCreditTextKey = Key('dataset_credit_text');
const Key _datasetCreditUrlKey = Key('dataset_credit_url');

/// The stored settings JSON the Task-9 provider loads
/// (`saint_app_settings`): [favorites] favorite slugs plus [recents]
/// recent slugs in most-recent-first order.
Map<String, Object> _prefsSeed({
  List<String> favorites = const <String>[],
  List<String> recents = const <String>[],
}) {
  return <String, Object>{
    SaintAppSettingsNotifier.storageKey: json.encode(<String, dynamic>{
      'favoriteSlugs': favorites,
      'recentSlugs': recents,
    }),
  };
}

void main() {
  /// Pumps the settings screen over an `UncontrolledProviderScope`. The mock
  /// SharedPreferences store is seeded BEFORE the container is created
  /// (Task-9/15 pattern) and the settings notifier's fire-and-forget load is
  /// drained inside `tester.runAsync`, so counts render synchronously.
  Future<ProviderContainer> pumpSettingsScreen(
    WidgetTester tester, {
    required Map<String, Object> prefsSeed,
  }) async {
    // The screen is one long ListView with lazy sliver children; enlarge the
    // test viewport so the whole composition materializes (the default
    // on-screen window otherwise leaves the lower sections unbuilt) and the
    // finders can reach every keyed section.
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(prefsSeed);
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      // Construct the settings notifier (starts its fire-and-forget async
      // load against the seeded mock store) and drain the load.
      container.read(saintAppSettingsProvider.notifier);
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('renders every shared settings widget type', (
    WidgetTester tester,
  ) async {
    await pumpSettingsScreen(tester, prefsSeed: _prefsSeed());

    // The shared composition, in the liturgical app's order. (AppInfo is
    // the shared-ui configuration object handed to AppInfoSection, so its
    // wiring is verified through the section's tiles below.)
    expect(find.byType(ThemeModeSelector), findsOneWidget);
    expect(find.byType(ColorIntensitySelector), findsOneWidget);
    expect(find.byType(LiturgicalColorPreview), findsOneWidget);
    expect(find.byType(AccessibilitySettings), findsOneWidget);
    expect(find.byType(LanguageSelector), findsOneWidget);
    expect(find.byType(AppInfoSection), findsOneWidget);
    // AppInfo composition lands as the section's about/version/support tiles.
    expect(find.text('Version'), findsOneWidget);
    expect(find.text('Send Feedback'), findsOneWidget);
    expect(find.text('Support Development'), findsOneWidget);

    // The app data section and the dataset credit section render too.
    expect(find.byKey(_appDataSectionKey), findsOneWidget);
    expect(find.byKey(_datasetCreditSectionKey), findsOneWidget);
  });

  testWidgets(
    'app data section shows zeroed counts and the saints data version',
    (WidgetTester tester) async {
      await pumpSettingsScreen(tester, prefsSeed: _prefsSeed());

      expect(find.byKey(_appDataSectionKey), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(_favoritesCountKey)).data,
        '0 saints saved',
      );
      expect(
        tester.widget<Text>(find.byKey(_recentsCountKey)).data,
        '0 saints viewed recently',
      );
      // Data version = the saints schema version constant (the bundled
      // asset's PRAGMA user_version), rendered as text.
      expect(
        tester.widget<Text>(find.byKey(_dataVersionKey)).data,
        'Data version 1',
      );
    },
  );

  testWidgets('counts update with seeded settings and stay live on toggle', (
    WidgetTester tester,
  ) async {
    // Seeded: two favorites, one recent — different from the defaults, so
    // the counts reflect the stored settings rather than static zero.
    final ProviderContainer container = await pumpSettingsScreen(
      tester,
      prefsSeed: _prefsSeed(
        favorites: <String>['anthony-of-padua', 'joan-of-arc'],
        recents: <String>['therese-of-lisieux'],
      ),
    );

    expect(
      tester.widget<Text>(find.byKey(_favoritesCountKey)).data,
      '2 saints saved',
    );
    expect(
      tester.widget<Text>(find.byKey(_recentsCountKey)).data,
      '1 saints viewed recently',
    );

    // Live update: the provider's synchronous state rebuilds the section.
    // 'therese-of-lisieux' is seeded into recents only, so favoriting it is
    // a pure add (2 favorites + 1).
    await container
        .read(saintAppSettingsProvider.notifier)
        .toggleFavorite('therese-of-lisieux');
    await tester.pump();

    expect(
      tester.widget<Text>(find.byKey(_favoritesCountKey)).data,
      '3 saints saved',
    );
  });

  testWidgets(
    'dataset credit carries the exact upstream wording and launch-less URL text',
    (WidgetTester tester) async {
      await pumpSettingsScreen(tester, prefsSeed: _prefsSeed());

      expect(find.byKey(_datasetCreditSectionKey), findsOneWidget);

      // Spec §12 credit wording, carried from the web app.
      final String creditText =
          tester.widget<Text>(find.byKey(_datasetCreditTextKey)).data ?? '';
      expect(creditText, contains('There Is a Saint for That'));
      expect(creditText, contains("by Peter's Barque"));

      // Upstream attribution link as PLAIN text (detail-sources tiles
      // convention: no launcher dependency, the URL itself is the content —
      // a plain `Text` widget carries no tap recognizer to launch it).
      final Text urlText = tester.widget<Text>(
        find.byKey(_datasetCreditUrlKey),
      );
      expect(urlText.data, 'https://www.youtube.com/watch?v=9lEUN28c0oc');
    },
  );
}
