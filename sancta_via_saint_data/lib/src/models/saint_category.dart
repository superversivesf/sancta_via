/// Patronage categories for saints, matching the saint-for-that taxonomy.
///
/// Ids, labels, and descriptions are verbatim from
/// `saint-for-that/site/src/lib/taxonomy.ts` (CATEGORIES).
enum SaintCategory {
  /// Lost items, housework, errands, daily needs.
  everyday('Everyday life', 'Lost items, housework, errands, daily needs'),

  /// Diseases, mental health, specific conditions.
  illness('Illness & healing', 'Diseases, mental health, specific conditions'),

  /// Vocations, trades, occupations.
  jobs('Jobs & professions', 'Vocations, trades, occupations'),

  /// Travelers, drivers, sailors, aviators.
  travel('Travel & transport', 'Travelers, drivers, sailors, aviators'),

  /// Martyrs, oppressed, prisoners, refugees.
  persecution(
    'Persecution & prisoners',
    'Martyrs, oppressed, prisoners, refugees',
  ),

  /// Doubt, conversion, prayer, temptations.
  spiritual('Spiritual life', 'Doubt, conversion, prayer, temptations'),

  /// Soldiers, police, firefighters, EMS.
  military(
    'Military & first responders',
    'Soldiers, police, firefighters, EMS',
  ),

  /// Children, mothers, fathers, fertility, marriage.
  family(
    'Children & family',
    'Children, mothers, fathers, fertility, marriage',
  ),

  /// Pets, ecology, environment, weather.
  nature('Animals & nature', 'Pets, ecology, environment, weather'),

  /// Impossible causes, the dying, the poor.
  special('Special intentions', 'Impossible causes, the dying, the poor');

  const SaintCategory(this.label, this.description);

  /// Human-readable label, verbatim from the source taxonomy.
  final String label;

  /// Short description, verbatim from the source taxonomy.
  final String description;

  /// The category whose id matches, or `null` for unknown ids.
  static SaintCategory? tryParse(String id) {
    for (final SaintCategory category in SaintCategory.values) {
      if (category.name == id) {
        return category;
      }
    }
    return null;
  }
}
