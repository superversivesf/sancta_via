import '../models/mystery_type.dart';

class RosaryProgressService {
  static const int totalBeads = 53;
  static const int introductoryBeads = 4;
  static const int beadsPerDecade = 11;
  static const int decadesPerRosary = 5;

  static Map<String, int> calculateProgress(int completedBeads) {
    if (completedBeads < 0 || completedBeads > totalBeads) {
      throw ArgumentError(
        'completedBeads must be between 0 and $totalBeads, got $completedBeads',
      );
    }

    final progressPercentage = (completedBeads / totalBeads * 100)
        .round()
        .clamp(0, 100);

    int currentDecade;
    int beadsInCurrentDecade;

    if (completedBeads <= introductoryBeads) {
      currentDecade = 0;
      beadsInCurrentDecade = completedBeads;
    } else {
      final beadsAfterIntro = completedBeads - introductoryBeads;
      currentDecade = (beadsAfterIntro / beadsPerDecade).ceil().clamp(
        1,
        decadesPerRosary,
      );
      beadsInCurrentDecade = (beadsAfterIntro - 1) % beadsPerDecade + 1;
    }

    return {
      'progressPercentage': progressPercentage,
      'currentDecade': currentDecade,
      'beadsInCurrentDecade': beadsInCurrentDecade,
    };
  }

  static MysteryType getDailyMysteryType(DateTime date) {
    if (date == null) {
      throw ArgumentError('date cannot be null');
    }

    switch (date.weekday) {
      case DateTime.monday:
        return MysteryType.joyful;
      case DateTime.tuesday:
        return MysteryType.sorrowful;
      case DateTime.wednesday:
        return MysteryType.glorious;
      case DateTime.thursday:
        return MysteryType.luminous;
      case DateTime.friday:
        return MysteryType.sorrowful;
      case DateTime.saturday:
        return MysteryType.joyful;
      case DateTime.sunday:
        return MysteryType.glorious;
      default:
        return MysteryType.joyful;
    }
  }

  static int getNextBeadIndex(int currentIndex) {
    if (currentIndex < 0) {
      throw ArgumentError(
        'currentIndex must be non-negative, got $currentIndex',
      );
    }

    if (currentIndex >= totalBeads) {
      return totalBeads;
    }

    return currentIndex + 1;
  }

  static bool isRosaryComplete(int completedBeads) {
    if (completedBeads < 0 || completedBeads > totalBeads) {
      throw ArgumentError(
        'completedBeads must be between 0 and $totalBeads, got $completedBeads',
      );
    }

    return completedBeads >= totalBeads;
  }

  static int getBeadsRemaining(int completedBeads) {
    if (completedBeads < 0 || completedBeads > totalBeads) {
      throw ArgumentError(
        'completedBeads must be between 0 and $totalBeads, got $completedBeads',
      );
    }

    return totalBeads - completedBeads;
  }

  static bool isInIntroductoryPrayers(int completedBeads) {
    if (completedBeads < 0 || completedBeads > totalBeads) {
      throw ArgumentError(
        'completedBeads must be between 0 and $totalBeads, got $completedBeads',
      );
    }

    return completedBeads < introductoryBeads;
  }

  static int getCurrentMysteryNumber(int completedBeads) {
    if (completedBeads <= introductoryBeads) {
      return 0;
    }

    final beadsAfterIntro = completedBeads - introductoryBeads;
    return (beadsAfterIntro / beadsPerDecade).ceil().clamp(1, decadesPerRosary);
  }

  static double estimateCompletionTime(
    int completedBeads,
    Duration averageTimePerBead,
  ) {
    if (completedBeads < 0 || completedBeads > totalBeads) {
      throw ArgumentError(
        'completedBeads must be between 0 and $totalBeads, got $completedBeads',
      );
    }

    final beadsRemaining = getBeadsRemaining(completedBeads);
    return beadsRemaining * averageTimePerBead.inMilliseconds.toDouble();
  }
}
