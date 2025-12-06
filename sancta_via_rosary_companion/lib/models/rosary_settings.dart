import 'color_intensity.dart';

class RosarySettings {
  const RosarySettings({
    required this.useDailySchedule,
    this.preferredMystery,
    required this.showFullText,
    required this.enableBeadCounter,
    required this.autoAdvance,
    required this.fontSize,
    required this.showImagery,
    this.colorIntensity,
  });

  final bool useDailySchedule;
  final String? preferredMystery;
  final bool showFullText;
  final bool enableBeadCounter;
  final bool autoAdvance;
  final double fontSize;
  final bool showImagery;
  final ColorIntensity? colorIntensity;

  RosarySettings copyWith({
    bool? useDailySchedule,
    String? preferredMystery,
    bool? showFullText,
    bool? enableBeadCounter,
    bool? autoAdvance,
    double? fontSize,
    bool? showImagery,
    ColorIntensity? colorIntensity,
  }) {
    return RosarySettings(
      useDailySchedule: useDailySchedule ?? this.useDailySchedule,
      preferredMystery: preferredMystery ?? this.preferredMystery,
      showFullText: showFullText ?? this.showFullText,
      enableBeadCounter: enableBeadCounter ?? this.enableBeadCounter,
      autoAdvance: autoAdvance ?? this.autoAdvance,
      fontSize: fontSize ?? this.fontSize,
      showImagery: showImagery ?? this.showImagery,
      colorIntensity: colorIntensity ?? this.colorIntensity,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RosarySettings &&
        other.useDailySchedule == useDailySchedule &&
        other.preferredMystery == preferredMystery &&
        other.showFullText == showFullText &&
        other.enableBeadCounter == enableBeadCounter &&
        other.autoAdvance == autoAdvance &&
        other.fontSize == fontSize &&
        other.showImagery == showImagery &&
        other.colorIntensity == colorIntensity;
  }

  @override
  int get hashCode =>
      useDailySchedule.hashCode ^
      preferredMystery.hashCode ^
      showFullText.hashCode ^
      enableBeadCounter.hashCode ^
      autoAdvance.hashCode ^
      fontSize.hashCode ^
      showImagery.hashCode ^
      colorIntensity.hashCode;
}
