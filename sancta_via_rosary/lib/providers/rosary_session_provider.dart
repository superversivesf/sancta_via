import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';

/// State for the current rosary prayer session
class RosaryPrayerState {
  final MysterySet mysterySet;
  final int currentMystery;
  final int currentDecadePosition;
  final bool isComplete;
  final bool showClosing;

  const RosaryPrayerState({
    required this.mysterySet,
    this.currentMystery = 0, // 0 = opening prayers, 1-5 = decades
    this.currentDecadePosition = 0,
    this.isComplete = false,
    this.showClosing = false,
  });

  RosaryPrayerState copyWith({
    MysterySet? mysterySet,
    int? currentMystery,
    int? currentDecadePosition,
    bool? isComplete,
    bool? showClosing,
  }) {
    return RosaryPrayerState(
      mysterySet: mysterySet ?? this.mysterySet,
      currentMystery: currentMystery ?? this.currentMystery,
      currentDecadePosition:
          currentDecadePosition ?? this.currentDecadePosition,
      isComplete: isComplete ?? this.isComplete,
      showClosing: showClosing ?? this.showClosing,
    );
  }

  /// Get current prayer step type
  PrayerStep get currentStep {
    if (isComplete) return PrayerStep.complete;
    if (showClosing) return PrayerStep.closing;
    if (currentMystery == 0) {
      return PrayerStep.opening;
    }
    // Within a decade
    if (currentDecadePosition == 0) return PrayerStep.announceMystery;
    if (currentDecadePosition == 1) return PrayerStep.ourFather;
    if (currentDecadePosition >= 2 && currentDecadePosition <= 11) {
      return PrayerStep.hailMary;
    }
    if (currentDecadePosition == 12) return PrayerStep.gloryBe;
    if (currentDecadePosition == 13) return PrayerStep.fatima;
    return PrayerStep.closing;
  }

  /// Get the specific prayer type for audio playback
  PrayerType get currentPrayerType {
    if (isComplete) return PrayerType.closing; // Or a default
    if (showClosing) return PrayerType.closing;
    if (currentMystery == 0) {
      // Opening prayers: positions 0-4
      // 0: Sign of the Cross
      // 1: Apostles' Creed
      // 2: Our Father
      // 3-4: Hail Mary (3 Hail Marys)
      switch (currentDecadePosition) {
        case 0:
          return PrayerType.signOfCross;
        case 1:
          return PrayerType.apostlesCreed;
        case 2:
          return PrayerType.openingOurFather;
        case 3:
        case 4:
          return PrayerType.openingHailMary;
        default:
          return PrayerType.signOfCross;
      }
    }
    // Within a decade
    if (currentDecadePosition == 0) return PrayerType.mystery;
    if (currentDecadePosition == 1) return PrayerType.ourFather;
    if (currentDecadePosition >= 2 && currentDecadePosition <= 11) {
      return PrayerType.hailMary;
    }
    if (currentDecadePosition == 12) return PrayerType.gloryBe;
    if (currentDecadePosition == 13) return PrayerType.fatimaPrayer;
    return PrayerType.closing;
  }

  /// Which Hail Mary are we on (1-10)
  int get hailMaryNumber =>
      currentDecadePosition >= 2 && currentDecadePosition <= 11
      ? currentDecadePosition - 1
      : 0;

  /// Progress through current decade (0-13)
  int get decadeProgress => currentDecadePosition;

  /// Total progress percentage (0-100)
  double get totalProgress {
    if (isComplete) return 100;
    if (showClosing) return 95;

    // Opening prayers: positions 0-4 (sign of cross, creed, our father, 3 hail marys)
    if (currentMystery == 0) {
      return (currentDecadePosition / 5) * 10; // First 10%
    }

    // Each decade is ~17% (5 decades = 85% after opening)
    final baseProgress = 10.0;
    final decadeProgress = (currentMystery - 1) * 17;
    final withinDecade = (currentDecadePosition / 14) * 17;

    return baseProgress + decadeProgress + withinDecade;
  }

  /// Get current bead position (for visual indicator)
  int get beadPosition {
    if (currentStep == PrayerStep.hailMary) {
      return hailMaryNumber - 1; // 0-indexed for bead indicator
    }
    return -1; // Not on Hail Marys
  }
}

/// Steps in the rosary prayer flow
enum PrayerStep {
  opening,
  announceMystery,
  ourFather,
  hailMary,
  gloryBe,
  fatima,
  closing,
  complete,
}

/// Notifier for managing rosary prayer session state
class RosaryPrayerNotifier extends StateNotifier<RosaryPrayerState> {
  final List<Mystery>? _mysteries;

  RosaryPrayerNotifier({
    required MysterySet mysterySet,
    List<Mystery>? mysteries,
  }) : _mysteries = mysteries,
       super(RosaryPrayerState(mysterySet: mysterySet));

  /// Advance to the next prayer
  void next() {
    HapticFeedback.lightImpact();

    if (state.isComplete) return;

    if (state.showClosing) {
      state = state.copyWith(isComplete: true);
      return;
    }

    // Opening prayers
    if (state.currentMystery == 0) {
      if (state.currentDecadePosition < 4) {
        state = state.copyWith(
          currentDecadePosition: state.currentDecadePosition + 1,
        );
      } else {
        // Move to first mystery
        state = state.copyWith(currentMystery: 1, currentDecadePosition: 0);
      }
      return;
    }

    // Within a decade
    if (state.currentDecadePosition < 13) {
      state = state.copyWith(
        currentDecadePosition: state.currentDecadePosition + 1,
      );
    } else {
      // Move to next mystery or closing
      if (state.currentMystery < 5) {
        state = state.copyWith(
          currentMystery: state.currentMystery + 1,
          currentDecadePosition: 0,
        );
      } else {
        state = state.copyWith(showClosing: true);
      }
    }
  }

  /// Go back to the previous prayer
  void previous() {
    HapticFeedback.lightImpact();

    if (state.isComplete) {
      state = state.copyWith(isComplete: false, showClosing: true);
      return;
    }

    if (state.showClosing) {
      state = state.copyWith(showClosing: false);
      return;
    }

    // Within opening prayers
    if (state.currentMystery == 0) {
      if (state.currentDecadePosition > 0) {
        state = state.copyWith(
          currentDecadePosition: state.currentDecadePosition - 1,
        );
      }
      return;
    }

    // Within a decade
    if (state.currentDecadePosition > 0) {
      state = state.copyWith(
        currentDecadePosition: state.currentDecadePosition - 1,
      );
    } else {
      // Move to previous mystery's end
      if (state.currentMystery > 1) {
        state = state.copyWith(
          currentMystery: state.currentMystery - 1,
          currentDecadePosition: 13, // End of previous decade
        );
      } else {
        // Back to opening prayers
        state = state.copyWith(currentMystery: 0, currentDecadePosition: 4);
      }
    }
  }

  /// Jump to a specific mystery (for mystery selection screen)
  void goToMystery(int mysteryNumber) {
    if (mysteryNumber < 1 || mysteryNumber > 5) return;
    state = state.copyWith(
      currentMystery: mysteryNumber,
      currentDecadePosition: 0,
      showClosing: false,
    );
  }

  /// Reset to the beginning
  void reset() {
    state = RosaryPrayerState(mysterySet: state.mysterySet);
  }

  /// Get current mystery
  Mystery? get currentMysteryData {
    if (_mysteries == null ||
        state.currentMystery < 1 ||
        state.currentMystery > 5) {
      return null;
    }
    return _mysteries[state.currentMystery - 1];
  }
}

/// Provider for the rosary session notifier
final rosarySessionProvider =
    StateNotifierProvider.family<
      RosaryPrayerNotifier,
      RosaryPrayerState,
      MysterySet
    >((ref, mysterySet) {
      // Get mysteries for this set
      final mysteries = ref.watch(mysteriesForSetProvider(mysterySet));
      return RosaryPrayerNotifier(mysterySet: mysterySet, mysteries: mysteries);
    });

/// Provider for mysteries in a specific set
final mysteriesForSetProvider = Provider.family<List<Mystery>, MysterySet>((
  ref,
  mysterySet,
) {
  // This would be populated from a repository
  // For now, return placeholder data
  return _getMysteriesForSet(mysterySet);
});

/// Placeholder data for mysteries
List<Mystery> _getMysteriesForSet(MysterySet set) {
  final joyfulMysteries = [
    const Mystery(
      id: 'joyful-1',
      name: 'The Annunciation',
      mysterySet: MysterySet.joyful,
      number: 1,
      fruit: 'Humility',
      scripture: 'Luke 1:26-38',
      description:
          'The Angel Gabriel appears to Mary, announcing that she will conceive and bear the Son of God.',
    ),
    const Mystery(
      id: 'joyful-2',
      name: 'The Visitation',
      mysterySet: MysterySet.joyful,
      number: 2,
      fruit: 'Love of Neighbor',
      scripture: 'Luke 1:39-56',
      description:
          'Mary visits her cousin Elizabeth, who recognizes Mary as the Mother of the Lord.',
    ),
    const Mystery(
      id: 'joyful-3',
      name: 'The Nativity',
      mysterySet: MysterySet.joyful,
      number: 3,
      fruit: 'Poverty of Spirit',
      scripture: 'Luke 2:1-20',
      description:
          'Jesus is born in Bethlehem in a humble stable, laid in a manger.',
    ),
    const Mystery(
      id: 'joyful-4',
      name: 'The Presentation',
      mysterySet: MysterySet.joyful,
      number: 4,
      fruit: 'Obedience',
      scripture: 'Luke 2:22-38',
      description:
          'Mary and Joseph present Jesus in the Temple according to Jewish law.',
    ),
    const Mystery(
      id: 'joyful-5',
      name: 'The Finding in the Temple',
      mysterySet: MysterySet.joyful,
      number: 5,
      fruit: 'Joy in Finding Jesus',
      scripture: 'Luke 2:41-52',
      description:
          'The boy Jesus is found in the Temple, speaking with the teachers.',
    ),
  ];

  final sorrowfulMysteries = [
    const Mystery(
      id: 'sorrowful-1',
      name: 'The Agony in the Garden',
      mysterySet: MysterySet.sorrowful,
      number: 1,
      fruit: 'Contrition',
      scripture: 'Matthew 26:36-46',
      description:
          'Jesus prays in the Garden of Gethsemane, accepting the Father\'s will.',
    ),
    const Mystery(
      id: 'sorrowful-2',
      name: 'The Scourging at the Pillar',
      mysterySet: MysterySet.sorrowful,
      number: 2,
      fruit: 'Purity',
      scripture: 'Matthew 27:26',
      description: 'Jesus is whipped at the pillar, suffering for our sins.',
    ),
    const Mystery(
      id: 'sorrowful-3',
      name: 'The Crowning with Thorns',
      mysterySet: MysterySet.sorrowful,
      number: 3,
      fruit: 'Moral Courage',
      scripture: 'Matthew 27:27-31',
      description:
          'Jesus is crowned with thorns and mocked as King of the Jews.',
    ),
    const Mystery(
      id: 'sorrowful-4',
      name: 'The Carrying of the Cross',
      mysterySet: MysterySet.sorrowful,
      number: 4,
      fruit: 'Patience',
      scripture: 'John 19:17',
      description:
          'Jesus carries the cross to Calvary, meeting his Mother along the way.',
    ),
    const Mystery(
      id: 'sorrowful-5',
      name: 'The Crucifixion',
      mysterySet: MysterySet.sorrowful,
      number: 5,
      fruit: 'Perseverance',
      scripture: 'Matthew 27:33-56',
      description: 'Jesus dies on the cross for our salvation.',
    ),
  ];

  final gloriousMysteries = [
    const Mystery(
      id: 'glorious-1',
      name: 'The Resurrection',
      mysterySet: MysterySet.glorious,
      number: 1,
      fruit: 'Faith',
      scripture: 'Matthew 28:1-10',
      description: 'Jesus rises from the dead, conquering sin and death.',
    ),
    const Mystery(
      id: 'glorious-2',
      name: 'The Ascension',
      mysterySet: MysterySet.glorious,
      number: 2,
      fruit: 'Hope',
      scripture: 'Luke 24:50-53',
      description:
          'Jesus ascends into heaven and sits at the right hand of the Father.',
    ),
    const Mystery(
      id: 'glorious-3',
      name: 'The Descent of the Holy Spirit',
      mysterySet: MysterySet.glorious,
      number: 3,
      fruit: 'Love',
      scripture: 'Acts 2:1-4',
      description: 'The Holy Spirit descends upon the Apostles at Pentecost.',
    ),
    const Mystery(
      id: 'glorious-4',
      name: 'The Assumption',
      mysterySet: MysterySet.glorious,
      number: 4,
      fruit: 'Devotion to Mary',
      scripture: 'Revelation 12:1',
      description: 'Mary is assumed body and soul into heaven.',
    ),
    const Mystery(
      id: 'glorious-5',
      name: 'The Coronation',
      mysterySet: MysterySet.glorious,
      number: 5,
      fruit: 'Eternal Happiness',
      scripture: 'Revelation 12:1',
      description: 'Mary is crowned Queen of Heaven and Earth.',
    ),
  ];

  final luminousMysteries = [
    const Mystery(
      id: 'luminous-1',
      name: 'The Baptism of Jesus',
      mysterySet: MysterySet.luminous,
      number: 1,
      fruit: 'Openness to the Holy Spirit',
      scripture: 'Matthew 3:13-17',
      description: 'Jesus is baptized by John in the Jordan River.',
    ),
    const Mystery(
      id: 'luminous-2',
      name: 'The Wedding at Cana',
      mysterySet: MysterySet.luminous,
      number: 2,
      fruit: 'To Jesus Through Mary',
      scripture: 'John 2:1-12',
      description:
          'At Mary\'s request, Jesus performs his first miracle at Cana.',
    ),
    const Mystery(
      id: 'luminous-3',
      name: 'The Proclamation of the Kingdom',
      mysterySet: MysterySet.luminous,
      number: 3,
      fruit: 'Repentance and Trust in God',
      scripture: 'Mark 1:14-15',
      description:
          'Jesus proclaims the coming of the Kingdom and calls us to conversion.',
    ),
    const Mystery(
      id: 'luminous-4',
      name: 'The Transfiguration',
      mysterySet: MysterySet.luminous,
      number: 4,
      fruit: 'Desire for Holiness',
      scripture: 'Matthew 17:1-8',
      description:
          'Jesus is transfigured before Peter, James, and John on Mount Tabor.',
    ),
    const Mystery(
      id: 'luminous-5',
      name: 'The Institution of the Eucharist',
      mysterySet: MysterySet.luminous,
      number: 5,
      fruit: 'Adoration',
      scripture: 'Matthew 26:26-28',
      description:
          'At the Last Supper, Jesus institutes the Eucharist for all time.',
    ),
  ];

  switch (set) {
    case MysterySet.joyful:
      return joyfulMysteries;
    case MysterySet.sorrowful:
      return sorrowfulMysteries;
    case MysterySet.glorious:
      return gloriousMysteries;
    case MysterySet.luminous:
      return luminousMysteries;
  }
}
