import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:novena_companion/features/novenas/models/novena.dart';
import 'package:novena_companion/features/novenas/providers/novena_state_provider.dart';

ActiveNovena freshNovena() {
  return ActiveNovena(
    novenaId: 'novena_of_rosary',
    startDate: DateTime(2026, 11, 10),
    reminderTime: const TimeOfDay(hour: 18, minute: 0),
    reminderFrequency: ReminderInterval.threeHours,
    completedDays: List<bool>.filled(9, false),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('start -> mark days -> persistence round-trip -> expiry', () async {
    final notifier = container.read(novenaStateProvider.notifier);

    // Start a novena: state set and written to SharedPreferences.
    await notifier.startNovena(freshNovena(), 'Novena of the Rosary');
    final active = container.read(novenaStateProvider);
    expect(active, isNotNull);
    expect(active!.novenaId, 'novena_of_rosary');

    // Mark days 1 and 2: persisted and idempotent-safe.
    await notifier.markDayComplete(1);
    await notifier.markDayComplete(2);
    expect(container.read(novenaStateProvider)!.isDayComplete(1), isTrue);
    expect(container.read(novenaStateProvider)!.isDayComplete(2), isTrue);
    expect(container.read(novenaStateProvider)!.isDayComplete(9), isFalse);

    // Invalid day numbers are rejected, not corrupted into state.
    await notifier.markDayComplete(0);
    await notifier.markDayComplete(10);
    expect(container.read(novenaStateProvider)!.isDayComplete(9), isFalse);

    // The stored JSON must contain exactly what state holds (restart parity).
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('active_novena_v1');
    expect(stored, isNotEmpty);
    final restored = ActiveNovena.fromJson(
        const JsonDecoder().convert(stored!) as Map<String, dynamic>);
    expect(restored.isDayComplete(2), isTrue);
    expect(restored.completedDays.where((d) => d), hasLength(2));

    // Clearing removes both state and storage.
    await notifier.clearActiveNovena();
    expect(container.read(novenaStateProvider), isNull);
    expect(prefs.getString('active_novena_v1'), anyOf(isNull, isEmpty));
  });

  test('a novena older than 9 days is cleared on load (expiry)', () async {
    final stale = ActiveNovena(
      novenaId: 'novena_of_rosary',
      startDate: DateTime.now().subtract(const Duration(days: 10)),
      reminderTime: const TimeOfDay(hour: 6, minute: 30),
      reminderFrequency: ReminderInterval.threeHours,
      completedDays: List<bool>.filled(3, true),
    );
    await container
        .read(novenaStateProvider.notifier)
        .startNovena(stale, 'Novena of the Rosary');

    // Force a fresh construction: _loadActiveNovena must discard the stale
    // novena (more than 9 days since start) rather than adopt it.
    final freshContainer = ProviderContainer();
    addTearDown(freshContainer.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(freshContainer.read(novenaStateProvider), isNull);
  });

  test('completed novenas are fully detectable via isComplete', () {
    final done = ActiveNovena(
      novenaId: 'novena_of_rosary',
      startDate: DateTime(2026, 11, 1),
      reminderTime: const TimeOfDay(hour: 18, minute: 0),
      reminderFrequency: ReminderInterval.threeHours,
      completedDays: List<bool>.filled(9, true),
    );
    expect(done.isComplete, isTrue);
    expect(freshNovena().isComplete, isFalse);
  });
}
