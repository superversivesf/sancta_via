import 'bead_type.dart';

class RosaryBead {
  const RosaryBead({
    required this.id,
    required this.type,
    required this.decadePosition,
    required this.prayerText,
    this.audioUrl,
  });

  final String id;
  final BeadType type;
  final int decadePosition;
  final String prayerText;
  final String? audioUrl;

  bool get isHailMary => type == BeadType.hailMary;
  bool get isOurFather => type == BeadType.ourFather;
  bool get isGloryBe => type == BeadType.gloryBe;
  bool get isApostlesCreed => type == BeadType.apostlesCreed;
  bool get isHailHolyQueen => type == BeadType.hailHolyQueen;

  RosaryBead copyWith({
    String? id,
    BeadType? type,
    int? decadePosition,
    String? prayerText,
    String? audioUrl,
  }) {
    return RosaryBead(
      id: id ?? this.id,
      type: type ?? this.type,
      decadePosition: decadePosition ?? this.decadePosition,
      prayerText: prayerText ?? this.prayerText,
      audioUrl: audioUrl ?? this.audioUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RosaryBead &&
        other.id == id &&
        other.type == type &&
        other.decadePosition == decadePosition;
  }

  @override
  int get hashCode => id.hashCode ^ type.hashCode ^ decadePosition.hashCode;
}
