import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../repositories/rosary_repository.dart';

/// Provider for the RosaryRepository instance
final rosaryRepositoryProvider = Provider<RosaryRepository>((ref) {
  return RosaryRepository.instance;
});

/// Provider for all rosary prayers
final rosaryPrayersProvider = Provider<List<RosaryPrayer>>((ref) {
  final repository = ref.watch(rosaryRepositoryProvider);
  return repository.getPrayers();
});

/// Provider for all 20 mysteries
final allMysteriesProvider = Provider<List<Mystery>>((ref) {
  final repository = ref.watch(rosaryRepositoryProvider);
  return repository.getAllMysteries();
});

/// Provider for mysteries by set (use family for parameterized provider)
final mysteriesBySetProvider = Provider.family<List<Mystery>, MysterySet>((
  ref,
  set,
) {
  final repository = ref.watch(rosaryRepositoryProvider);
  return repository.getMysteries(set);
});

/// Provider for today's recommended mystery set
final todaysMysterySetProvider = Provider<MysterySet>((ref) {
  final repository = ref.watch(rosaryRepositoryProvider);
  return repository.getMysteryForToday();
});

/// Provider for the mystery set for a specific weekday (1-7)
final mysterySetForWeekdayProvider = Provider.family<MysterySet, int>((
  ref,
  weekday,
) {
  final repository = ref.watch(rosaryRepositoryProvider);
  return repository.getMysteryForDay(weekday);
});

/// Provider for a specific mystery by ID
final mysteryByIdProvider = Provider.family<Mystery?, String>((ref, id) {
  final allMysteries = ref.watch(allMysteriesProvider);
  try {
    return allMysteries.firstWhere((m) => m.id == id);
  } catch (e) {
    return null;
  }
});

/// Provider for a specific prayer by ID
final prayerByIdProvider = Provider.family<RosaryPrayer?, String>((ref, id) {
  final allPrayers = ref.watch(rosaryPrayersProvider);
  try {
    return allPrayers.firstWhere((p) => p.id == id);
  } catch (e) {
    return null;
  }
});

/// Provider for opening prayers only
final openingPrayersProvider = Provider<List<RosaryPrayer>>((ref) {
  final prayers = ref.watch(rosaryPrayersProvider);
  return prayers
      .where(
        (p) =>
            p.type == PrayerType.signOfCross ||
            p.type == PrayerType.apostlesCreed ||
            p.type == PrayerType.openingOurFather ||
            p.type == PrayerType.openingHailMary,
      )
      .toList()
    ..sort((a, b) => (a.sequenceOrder ?? 99).compareTo(b.sequenceOrder ?? 99));
});

/// Provider for closing prayers only
final closingPrayersProvider = Provider<List<RosaryPrayer>>((ref) {
  final prayers = ref.watch(rosaryPrayersProvider);
  return prayers.where((p) => p.type == PrayerType.closing).toList()
    ..sort((a, b) => (a.sequenceOrder ?? 99).compareTo(b.sequenceOrder ?? 99));
});

/// Provider for decade prayers (Our Father, Hail Mary, Glory Be, Fatima)
final decadePrayersProvider = Provider<List<RosaryPrayer>>((ref) {
  final prayers = ref.watch(rosaryPrayersProvider);
  return prayers.where((p) {
    return p.type == PrayerType.ourFather ||
        p.type == PrayerType.hailMary ||
        p.type == PrayerType.gloryBe ||
        p.type == PrayerType.fatimaPrayer;
  }).toList();
});

/// Notifier for selected mystery set
class SelectedMysterySetNotifier extends StateNotifier<MysterySet> {
  SelectedMysterySetNotifier() : super(MysterySet.forToday());

  void select(MysterySet set) {
    state = set;
  }

  void selectForToday() {
    state = MysterySet.forToday();
  }

  void selectForWeekday(int weekday) {
    state = MysterySet.forWeekday(weekday);
  }
}

/// Provider for user-selected mystery set (defaults to today's)
final selectedMysterySetProvider =
    StateNotifierProvider<SelectedMysterySetNotifier, MysterySet>(
      (ref) => SelectedMysterySetNotifier(),
    );

/// Provider for the currently selected mystery set's mysteries
final selectedMysteriesProvider = Provider<List<Mystery>>((ref) {
  final selectedSet = ref.watch(selectedMysterySetProvider);
  return ref.watch(mysteriesBySetProvider(selectedSet));
});

/// Notifier for current mystery number within a session (1-5)
class CurrentMysteryNumberNotifier extends StateNotifier<int> {
  CurrentMysteryNumberNotifier() : super(1);

  void setMystery(int number) {
    if (number >= 1 && number <= 5) {
      state = number;
    }
  }

  void next() {
    if (state < 5) {
      state = state + 1;
    }
  }

  void previous() {
    if (state > 1) {
      state = state - 1;
    }
  }

  void reset() {
    state = 1;
  }
}

/// Provider for current mystery number being prayed
final currentMysteryNumberProvider =
    StateNotifierProvider<CurrentMysteryNumberNotifier, int>(
      (ref) => CurrentMysteryNumberNotifier(),
    );

/// Provider for the current mystery being prayed
final currentMysteryProvider = Provider<Mystery?>((ref) {
  final currentNumber = ref.watch(currentMysteryNumberProvider);
  final mysteries = ref.watch(selectedMysteriesProvider);

  if (mysteries.isEmpty || currentNumber < 1 || currentNumber > 5) {
    return null;
  }

  try {
    return mysteries.firstWhere((m) => m.number == currentNumber);
  } catch (e) {
    return null;
  }
});

/// Notifier for Hail Mary count within current decade (0-10)
class HailMaryCountNotifier extends StateNotifier<int> {
  HailMaryCountNotifier() : super(0);

  void setCount(int count) {
    if (count >= 0 && count <= 10) {
      state = count;
    }
  }

  void increment() {
    if (state < 10) {
      state = state + 1;
    }
  }

  void decrement() {
    if (state > 0) {
      state = state - 1;
    }
  }

  void reset() {
    state = 0;
  }

  bool get isComplete => state >= 10;
}

/// Provider for current Hail Mary count in the decade
final hailMaryCountProvider = StateNotifierProvider<HailMaryCountNotifier, int>(
  (ref) => HailMaryCountNotifier(),
);

/// Provider for whether current decade is complete
final decadeCompleteProvider = Provider<bool>((ref) {
  final count = ref.watch(hailMaryCountProvider);
  return count >= 10;
});

/// Notifier for whether Fatima prayer is enabled
class FatimaPrayerEnabledNotifier extends StateNotifier<bool> {
  FatimaPrayerEnabledNotifier() : super(true);

  void toggle() {
    state = !state;
  }

  void setEnabled(bool enabled) {
    state = enabled;
  }
}

/// Provider for Fatima prayer preference
final fatimaPrayerEnabledProvider =
    StateNotifierProvider<FatimaPrayerEnabledNotifier, bool>(
      (ref) => FatimaPrayerEnabledNotifier(),
    );
