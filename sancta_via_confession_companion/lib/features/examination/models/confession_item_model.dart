class ConfessionItem {
  final String itemText;
  final String? note;
  final int? frequency; // Optional: how many times
  final bool isMortal; // Whether the sin is mortal (serious)

  ConfessionItem({
    required this.itemText,
    this.note,
    this.frequency,
    this.isMortal = false,
  });

  // Factory method from ExaminationItem and session data
  factory ConfessionItem.fromExaminationItem({
    required String itemText,
    String? note,
    bool isMortal = false,
    int? frequency,
  }) {
    return ConfessionItem(
      itemText: itemText,
      note: note,
      frequency: frequency,
      isMortal: isMortal,
    );
  }

  // Create a copy with updated fields
  ConfessionItem copyWith({
    String? itemText,
    String? note,
    int? frequency,
    bool? isMortal,
  }) {
    return ConfessionItem(
      itemText: itemText ?? this.itemText,
      note: note ?? this.note,
      frequency: frequency ?? this.frequency,
      isMortal: isMortal ?? this.isMortal,
    );
  }

  // For display purposes
  String getDisplayText() {
    String display = itemText;
    if (frequency != null && frequency! > 0) {
      display += ' ($frequency times)';
    }
    return display;
  }
}
