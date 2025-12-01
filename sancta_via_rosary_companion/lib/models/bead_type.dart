enum BeadType {
  ourFather('our_father'),
  hailMary('hail_mary'),
  gloryBe('glory_be'),
  apostlesCreed('apostles_creed'),
  hailHolyQueen('hail_holy_queen'),
  signOfCross('sign_of_cross'),
  finalPrayer('final_prayer');

  const BeadType(this.value);

  final String value;

  factory BeadType.fromString(String value) {
    return BeadType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => BeadType.hailMary,
    );
  }
}