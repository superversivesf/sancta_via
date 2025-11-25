/// Liturgical colors used in Catholic worship
enum LiturgicalColor {
  green('GREEN', 'Green'),
  purple('PURPLE', 'Purple'),
  rose('ROSE', 'Rose'),
  white('WHITE', 'White'),
  red('RED', 'Red'),
  gold('GOLD', 'Gold');

  const LiturgicalColor(this.code, this.displayName);

  final String code;
  final String displayName;

  /// Convert from string to enum
  static LiturgicalColor? fromString(String color) {
    switch (color.toUpperCase()) {
      case 'GREEN':
        return LiturgicalColor.green;
      case 'PURPLE':
        return LiturgicalColor.purple;
      case 'ROSE':
        return LiturgicalColor.rose;
      case 'WHITE':
        return LiturgicalColor.white;
      case 'RED':
        return LiturgicalColor.red;
      case 'GOLD':
        return LiturgicalColor.gold;
      default:
        return null;
    }
  }

  /// Get hex color code for UI representation
  String get hexColor {
    switch (this) {
      case LiturgicalColor.green:
        return '#228B22';
      case LiturgicalColor.purple:
        return '#800080';
      case LiturgicalColor.rose:
        return '#FF69B4';
      case LiturgicalColor.white:
        return '#FFFFFF';
      case LiturgicalColor.red:
        return '#DC143C';
      case LiturgicalColor.gold:
        return '#FFD700';
    }
  }
}

/// Liturgical seasons in the Catholic Church
enum LiturgicalSeason {
  advent('Advent'),
  christmas('Christmas'),
  christmastide('Christmastide'),
  ordinaryTime('Ordinary Time'),
  earlyOrdinaryTime('Early Ordinary Time'),
  lent('Lent'),
  holyWeek('Holy Week'),
  triduum('Triduum'),
  easter('Easter'),
  eastertide('Eastertide'),
  pentecost('Pentecost');

  const LiturgicalSeason(this.displayName);

  final String displayName;

  /// Convert from string to enum
  static LiturgicalSeason? fromString(String season) {
    switch (season.toLowerCase()) {
      case 'advent':
        return LiturgicalSeason.advent;
      case 'christmas':
      case 'christmastide':
        return LiturgicalSeason.christmas;
      case 'ordinary time':
      case 'early ordinary time':
        return LiturgicalSeason.ordinaryTime;
      case 'lent':
        return LiturgicalSeason.lent;
      case 'holy week':
        return LiturgicalSeason.holyWeek;
      case 'triduum':
        return LiturgicalSeason.triduum;
      case 'easter':
      case 'eastertide':
        return LiturgicalSeason.easter;
      case 'pentecost':
        return LiturgicalSeason.pentecost;
      default:
        return null;
    }
  }

  /// Get the default color for this season
  LiturgicalColor get defaultColor {
    switch (this) {
      case LiturgicalSeason.advent:
      case LiturgicalSeason.lent:
        return LiturgicalColor.purple;
      case LiturgicalSeason.christmas:
      case LiturgicalSeason.christmastide:
      case LiturgicalSeason.easter:
      case LiturgicalSeason.eastertide:
        return LiturgicalColor.white;
      case LiturgicalSeason.pentecost:
        return LiturgicalColor.red;
      case LiturgicalSeason.ordinaryTime:
      case LiturgicalSeason.earlyOrdinaryTime:
        return LiturgicalColor.green;
      case LiturgicalSeason.holyWeek:
      case LiturgicalSeason.triduum:
        return LiturgicalColor.red;
    }
  }
}
