/// Information about a liturgical year's data file
class YearInfo {
  final int year;
  final int totalDays;
  final int prioritizedCelebrations;
  final String file;

  const YearInfo({
    required this.year,
    required this.totalDays,
    required this.prioritizedCelebrations,
    required this.file,
  });

  factory YearInfo.fromJson(Map<String, dynamic> json) {
    return YearInfo(
      year: json['year'] ?? 0,
      totalDays: json['totalDays'] ?? 0,
      prioritizedCelebrations: json['prioritizedCelebrations'] ?? 0,
      file: json['file'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'year': year,
      'totalDays': totalDays,
      'prioritizedCelebrations': prioritizedCelebrations,
      'file': file,
    };
  }

  @override
  String toString() {
    return 'YearInfo(year: $year, file: $file, totalDays: $totalDays)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is YearInfo &&
            runtimeType == other.runtimeType &&
            year == other.year &&
            file == other.file;
  }

  @override
  int get hashCode => year.hashCode ^ file.hashCode;
}

/// Index of all available liturgical calendar data
class LiturgicalIndex {
  final String generatedAt;
  final String dataVersion;
  final String romcalVersion;
  final List<YearInfo> years;
  final int totalYears;

  const LiturgicalIndex({
    required this.generatedAt,
    required this.dataVersion,
    required this.romcalVersion,
    required this.years,
    required this.totalYears,
  });

  factory LiturgicalIndex.fromJson(Map<String, dynamic> json) {
    final yearsJson = json['years'] as List<dynamic>;
    final years = yearsJson.map((year) => YearInfo.fromJson(year)).toList();

    return LiturgicalIndex(
      generatedAt: json['generatedAt'] ?? '',
      dataVersion: json['dataVersion'] ?? '',
      romcalVersion: json['romcalVersion'] ?? '',
      years: years,
      totalYears: json['totalYears'] ?? years.length,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'generatedAt': generatedAt,
      'dataVersion': dataVersion,
      'romcalVersion': romcalVersion,
      'years': years.map((year) => year.toJson()).toList(),
      'totalYears': totalYears,
    };
  }

  /// Get year info for a specific year
  YearInfo? getYearInfo(int year) {
    try {
      return years.firstWhere((yearInfo) => yearInfo.year == year);
    } catch (e) {
      return null;
    }
  }

  /// Check if a year is available
  bool isYearAvailable(int year) {
    return years.any((yearInfo) => yearInfo.year == year);
  }

  /// Get list of available years
  List<int> get availableYears {
    return years.map((yearInfo) => yearInfo.year).toList()..sort();
  }

  /// Get year range
  ({int start, int end}) get yearRange {
    final availableYearsList = availableYears;
    if (availableYearsList.isEmpty) {
      return (start: 0, end: 0);
    }
    return (start: availableYearsList.first, end: availableYearsList.last);
  }

  @override
  String toString() {
    return 'LiturgicalIndex(totalYears: $totalYears, dataVersion: $dataVersion, romcalVersion: $romcalVersion)';
  }
}
