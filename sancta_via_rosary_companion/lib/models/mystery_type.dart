enum MysteryType {
  joyful('joyful'),
  sorrowful('sorrowful'),
  glorious('glorious'),
  luminous('luminous');

  const MysteryType(this.value);

  final String value;

  factory MysteryType.fromString(String value) {
    return MysteryType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => MysteryType.joyful,
    );
  }

  factory MysteryType.fromDate(DateTime date) {
    switch (date.weekday) {
      case 1:
        return MysteryType.joyful;
      case 2:
        return MysteryType.sorrowful;
      case 3:
        return MysteryType.glorious;
      case 4:
        return MysteryType.luminous;
      case 5:
        return MysteryType.sorrowful;
      case 6:
        return MysteryType.joyful;
      case 7:
        return MysteryType.glorious;
      default:
        return MysteryType.joyful;
    }
  }

  String get displayName {
    return '${value[0].toUpperCase()}${value.substring(1)} Mysteries';
  }
}