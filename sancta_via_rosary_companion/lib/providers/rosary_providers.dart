import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/rosary_bead.dart';
import '../models/rosary_session.dart';
import '../models/rosary_settings.dart';
import '../models/mystery_type.dart';
import '../models/bead_type.dart';
import '../models/rosary_mystery.dart';
import '../repositories/rosary_repository_impl.dart';

// Prayer progression providers
final currentMysteryIndexProvider = StateProvider<int>((ref) => 0);

final currentMysteryTypeProvider = StateProvider<String>((ref) => 'joyful');

final currentBeadIndexProvider = StateProvider<int>((ref) => 0);

final totalBeadsProvider = Provider<int>((ref) {
  final beadsList = ref.watch(prayerSequenceProvider);
  return beadsList.length;
});

final isPrayerCompleteProvider = Provider<bool>((ref) {
  final currentBeadIndex = ref.watch(currentBeadIndexProvider);
  final totalBeads = ref.watch(totalBeadsProvider);
  return currentBeadIndex >= totalBeads;
});

final prayerSequenceProvider = Provider<List<RosaryBead>>((ref) {
  final beads = <RosaryBead>[];

  // Initial prayers (Apostles Creed + 3 Hail Marys)
  beads.addAll([
    RosaryBead(
      id: 'apostles_creed',
      type: BeadType.apostlesCreed,
      decadePosition: 0,
      prayerText:
          'I believe in God, the Father almighty, creator of heaven and earth...',
    ),
    RosaryBead(
      id: 'our_father_1',
      type: BeadType.ourFather,
      decadePosition: 0,
      prayerText: 'Our Father, who art in heaven, hallowed be thy Name...',
    ),
    RosaryBead(
      id: 'hail_mary_1',
      type: BeadType.hailMary,
      decadePosition: 0,
      prayerText: 'Hail Mary, full of grace, the Lord is with thee...',
    ),
    RosaryBead(
      id: 'hail_mary_2',
      type: BeadType.hailMary,
      decadePosition: 0,
      prayerText: 'Hail Mary, full of grace, the Lord is with thee...',
    ),
    RosaryBead(
      id: 'hail_mary_3',
      type: BeadType.hailMary,
      decadePosition: 0,
      prayerText: 'Hail Mary, full of grace, the Lord is with thee...',
    ),
  ]);

  // Five decades
  for (int decade = 1; decade <= 5; decade++) {
    beads.add(
      RosaryBead(
        id: 'our_father_$decade',
        type: BeadType.ourFather,
        decadePosition: decade,
        prayerText: 'Our Father, who art in heaven, hallowed be thy Name...',
      ),
    );

    for (int hailMary = 1; hailMary <= 10; hailMary++) {
      beads.add(
        RosaryBead(
          id: 'hail_mary_${decade}_$hailMary',
          type: BeadType.hailMary,
          decadePosition: decade,
          prayerText: 'Hail Mary, full of grace, the Lord is with thee...',
        ),
      );
    }

    if (decade < 5) {
      beads.add(
        RosaryBead(
          id: 'glory_be_$decade',
          type: BeadType.gloryBe,
          decadePosition: decade,
          prayerText:
              'Glory be to the Father, and to the Son, and to the Holy Spirit...',
        ),
      );
    }
  }

  // Final prayer
  beads.add(
    RosaryBead(
      id: 'hail_holy_queen',
      type: BeadType.hailHolyQueen,
      decadePosition: 6,
      prayerText:
          'Hail, Holy Queen, Mother of Mercy, our life, our sweetness, and our hope...',
    ),
  );

  return beads;
});

final currentBeadProvider = Provider<RosaryBead>((ref) {
  final currentBeadIndex = ref.watch(currentBeadIndexProvider);
  final beadsList = ref.watch(prayerSequenceProvider);
  if (currentBeadIndex < beadsList.length) {
    return beadsList[currentBeadIndex];
  }
  return RosaryBead(
    id: 'complete',
    type: BeadType.hailHolyQueen,
    decadePosition: 6,
    prayerText:
        'Congratulations, you have completed the Rosary! May God bless you.',
  );
});

final currentDecadeProvider = Provider<int>((ref) {
  final currentBead = ref.watch(currentBeadProvider);
  return currentBead.decadePosition;
});

final rosarySettingsProvider =
    StateNotifierProvider<RosarySettingsNotifier, RosarySettings>((ref) {
      return RosarySettingsNotifier();
    });

class RosarySettingsNotifier extends StateNotifier<RosarySettings> {
  RosarySettingsNotifier()
    : super(
        const RosarySettings(
          useDailySchedule: true,
          showFullText: true,
          enableBeadCounter: true,
          autoAdvance: false,
          fontSize: 16.0,
          showImagery: true,
        ),
      );

  void toggleDailySchedule() {
    state = state.copyWith(useDailySchedule: !state.useDailySchedule);
  }

  void toggleShowFullText() {
    state = state.copyWith(showFullText: !state.showFullText);
  }

  void toggleBeadCounter() {
    state = state.copyWith(enableBeadCounter: !state.enableBeadCounter);
  }

  void toggleAutoAdvance() {
    state = state.copyWith(autoAdvance: !state.autoAdvance);
  }

  void updateFontSize(double fontSize) {
    state = state.copyWith(fontSize: fontSize);
  }

  void toggleShowImagery() {
    state = state.copyWith(showImagery: !state.showImagery);
  }
}

final activeSessionProvider =
    StateNotifierProvider<RosarySessionNotifier, RosarySession?>((ref) {
      return RosarySessionNotifier();
    });

class RosarySessionNotifier extends StateNotifier<RosarySession?> {
  RosarySessionNotifier() : super(null);

  void startSession(String mysteryType) {
    final session = RosarySession(
      id: DateTime.now().toIso8601String(),
      mysteryType: mysteryType,
      startTime: DateTime.now(),
      completedBeads: 0,
      isComplete: false,
    );
    state = session;
  }

  void updateProgress(int completedBeads) {
    if (state == null) return;
    state = state!.copyWith(completedBeads: completedBeads);
  }

  void completeSession({String? notes}) {
    if (state == null) return;
    state = state!.copyWith(
      endTime: DateTime.now(),
      isComplete: true,
      notes: notes,
      completedBeads: 53,
    );
  }

  void resetSession() {
    state = null;
  }
}

final prayerControllerProvider = Provider<PrayerController>((ref) {
  return PrayerController(ref);
});

// Add providers for dynamic mystery loading
final currentMysteriesProvider = FutureProvider<List<RosaryMystery>>((
  ref,
) async {
  final repository = RosaryRepositoryImpl();
  final mysteryType = ref.watch(currentMysteryTypeProvider);
  return await repository.getMysteriesByType(mysteryType);
});

final currentMysteryProvider = Provider<RosaryMystery?>((ref) {
  final mysteries = ref.watch(currentMysteriesProvider);
  final mysteryIndex = ref.watch(currentMysteryIndexProvider);

  return mysteries.when(
    data: (mysteriesList) => mysteryIndex < mysteriesList.length
        ? mysteriesList[mysteryIndex]
        : null,
    loading: () => null,
    error: (error, _) => null,
  );
});

class PrayerController {
  PrayerController(this._ref);

  final Ref _ref;

  void nextBead() {
    final currentIndex = _ref.read(currentBeadIndexProvider);
    final totalBeads = _ref.read(totalBeadsProvider);

    if (currentIndex < totalBeads - 1) {
      _ref.read(currentBeadIndexProvider.notifier).state = currentIndex + 1;
    }

    // Update session progress
    final session = _ref.read(activeSessionProvider);
    if (session != null) {
      _ref
          .read(activeSessionProvider.notifier)
          .updateProgress(currentIndex + 1);
    }
  }

  void previousBead() {
    final currentIndex = _ref.read(currentBeadIndexProvider);
    if (currentIndex > 0) {
      _ref.read(currentBeadIndexProvider.notifier).state = currentIndex - 1;
    }
  }

  void nextMystery() {
    final currentMysteryIndex = _ref.read(currentMysteryIndexProvider);
    if (currentMysteryIndex < 4) {
      _ref.read(currentMysteryIndexProvider.notifier).state =
          currentMysteryIndex + 1;
    }
  }

  void previousMystery() {
    final currentMysteryIndex = _ref.read(currentMysteryIndexProvider);
    if (currentMysteryIndex > 0) {
      _ref.read(currentMysteryIndexProvider.notifier).state =
          currentMysteryIndex - 1;
    }
  }

  void resetPrayer() {
    _ref.read(currentBeadIndexProvider.notifier).state = 0;
    _ref.read(currentMysteryIndexProvider.notifier).state = 0;
    _ref.read(activeSessionProvider.notifier).resetSession();
  }

  void startNewSession(String mysteryTypeDisplayName) {
    // Extract the mystery type from display name (e.g., "Joyful Mysteries" -> "joyful")
    final mysteryType = mysteryTypeDisplayName.toLowerCase().split(' ')[0];
    _ref.read(currentMysteryTypeProvider.notifier).state = mysteryType;
    _ref
        .read(activeSessionProvider.notifier)
        .startSession(mysteryTypeDisplayName);
    resetPrayer();
  }
}

// Daily mystery provider
final dailyMysteryProvider = Provider<MysteryType>((ref) {
  return MysteryType.fromDate(DateTime.now());
});
