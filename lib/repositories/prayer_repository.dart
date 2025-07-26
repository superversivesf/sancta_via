import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/prayer.dart';
import '../models/prayer_category.dart';
import '../models/prayer_category_group.dart';
import '../models/prayer_app_settings.dart';
import '../utils/logger.dart';

class PrayerRepository {
  static const String _prayersFolder = 'prayers';
  static const String _preferencesKey = 'prayer_preferences';

  // Define category groups directly in code since they're relatively static
  static final List<PrayerCategoryGroup> _categoryGroups = [
    PrayerCategoryGroup(
      id: 'essential',
      title: 'Essential Prayers',
      description: 'Core prayers every Catholic should know',
      icon: 'auto_awesome',
      order: 1,
    ),
    PrayerCategoryGroup(
      id: 'daily',
      title: 'Daily Prayers',
      description: 'Prayers for different times of day',
      icon: 'schedule',
      order: 2,
    ),
    PrayerCategoryGroup(
      id: 'liturgical',
      title: 'Liturgical Prayers',
      description: 'Prayers from the Mass and liturgy',
      icon: 'church',
      order: 3,
    ),
    PrayerCategoryGroup(
      id: 'marian',
      title: 'Marian Prayers',
      description: 'Prayers to the Blessed Virgin Mary',
      icon: 'favorite',
      order: 4,
    ),
    PrayerCategoryGroup(
      id: 'saints',
      title: 'Saints & Devotions',
      description: 'Prayers to saints and devotional prayers',
      icon: 'stars',
      order: 5,
    ),
    PrayerCategoryGroup(
      id: 'sacramental',
      title: 'Sacramental Prayers',
      description: 'Prayers for the sacraments',
      icon: 'water_drop',
      order: 6,
    ),
  ];

  // Define categories directly in code since they're relatively static
  static final List<PrayerCategory> _categories = [
    PrayerCategory(
      id: 'essential',
      title: 'Essential Prayers',
      description: 'Core prayers every Catholic should know',
      groupId: 'essential',
    ),
    PrayerCategory(
      id: 'morning',
      title: 'Morning Prayers',
      description: 'Prayers to start your day',
      groupId: 'daily',
    ),
    PrayerCategory(
      id: 'evening',
      title: 'Evening Prayers',
      description: 'Prayers to end your day',
      groupId: 'daily',
    ),
    PrayerCategory(
      id: 'mass',
      title: 'Mass Prayers',
      description: 'Prayers from the liturgy of the Mass',
      groupId: 'liturgical',
    ),
    PrayerCategory(
      id: 'marian',
      title: 'Marian Prayers',
      description: 'Prayers to the Blessed Virgin Mary',
      groupId: 'marian',
    ),
    PrayerCategory(
      id: 'saints',
      title: 'Prayers to Saints',
      description: 'Prayers to various saints',
      groupId: 'saints',
    ),
    PrayerCategory(
      id: 'confession',
      title: 'Confession Prayers',
      description: 'Prayers for the sacrament of reconciliation',
      groupId: 'sacramental',
    ),
  ];

  // Define the prayer file names directly since we need to know which files to load
  static const List<String> _prayerFileNames = [
    'sign_of_the_cross.json',
    'our_father.json',
    'hail_mary.json',
    'glory_be.json',
    'apostles_creed.json',
    'nicene_creed.json',
    'act_of_contrition.json',
    'guardian_angel_prayer.json',
    'act_of_faith_hope_charity.json',
    'eternal_rest.json',
    'morning_offering.json',
    'morning_thanksgiving.json',
    'morning_offering_mary.json',
    'morning_offering_simple.json',
    'grace_before_meals.json',
    'grace_after_meals.json',
    'evening_thanksgiving.json',
    'evening_protection.json',
    'prayer_before_sleep.json',
    'children_bedtime_prayer.json',
    'bedtime_examination.json',
    'away_in_manger_bedtime.json',
    'compline_commendation.json',
    'compline_protection.json',
    'nunc_dimittis.json',
    'compline_final_prayer.json',
    'gloria_in_excelsis.json',
    'sanctus.json',
    'memorial_acclamation_1.json',
    'memorial_acclamation_2.json',
    'memorial_acclamation_3.json',
    'agnus_dei.json',
    'prayer_before_mass.json',
    'anima_christi.json',
    'suscipe_prayer.json',
    'memorare.json',
    'angelus.json',
    'regina_caeli.json',
    'hail_holy_queen.json',
    'sub_tuum_praesidium.json',
    'prayer_to_immaculate_heart.json',
    'prayer_to_st_michael.json',
    'prayer_to_st_joseph.json',
    'st_francis_peace_prayer.json',
    'st_francis_san_damiano.json',
    'st_anthony_lost_things.json',
    'st_anthony_powerful_intercession.json',
    'st_therese_little_flower.json',
    'st_therese_morning_offering.json',
    'prayer_to_st_rita.json',
    'st_jude_novena.json',
    'st_jude_glorious_apostle.json',
    'st_teresa_bookmark_prayer.json',
    'christ_has_no_body.json',
    'prayer_to_st_teresa_intercession.json',
    'prayer_to_sacred_heart.json',
    'veni_creator_spiritus.json',
    'prayer_for_pope_formal.json',
    'prayer_for_pope_blessing.json',
  ];

  // Cache for loaded prayers
  List<Prayer>? _cachedPrayers;

  // Get all prayers
  Future<List<Prayer>> getAllPrayers() async {
    if (_cachedPrayers != null) {
      return _cachedPrayers!;
    }

    try {
      final List<Prayer> prayers = [];
      
      for (final fileName in _prayerFileNames) {
        try {
          final jsonString = await rootBundle.loadString('assets/$_prayersFolder/$fileName');
          final Map<String, dynamic> jsonData = json.decode(jsonString);
          final prayer = Prayer.fromJson(jsonData);
          prayers.add(prayer);
        } catch (e) {
          AppLogger.error('Error loading prayer file $fileName', e, null, 'PRAYER');
          // Continue loading other prayers even if one fails
        }
      }

      _cachedPrayers = prayers;
      return prayers;
    } catch (e) {
      AppLogger.error('Error loading prayers', e, null, 'PRAYER');
      return [];
    }
  }

  // Get prayer by ID
  Future<Prayer?> getPrayer(String prayerId) async {
    try {
      final prayers = await getAllPrayers();
      return prayers.firstWhere((prayer) => prayer.id == prayerId);
    } catch (e) {
      AppLogger.error('Error loading prayer $prayerId', e, null, 'PRAYER');
      return null;
    }
  }

  // Get user preferences (deprecated - use PrayerAppSettingsProvider instead)
  @Deprecated('Use PrayerAppSettingsProvider instead')
  Future<PrayerAppSettings> getUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_preferencesKey);

    if (jsonString == null) {
      return PrayerAppSettings.defaults();
    }

    return PrayerAppSettings.fromJson(json.decode(jsonString));
  }

  // Save user preferences (deprecated - use PrayerAppSettingsProvider instead)
  @Deprecated('Use PrayerAppSettingsProvider instead')
  Future<void> saveUserPreferences(PrayerAppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferencesKey, json.encode(settings.toJson()));
  }

  // Toggle favorite status (deprecated - use PrayerAppSettingsProvider instead)
  @Deprecated('Use PrayerAppSettingsProvider instead')
  Future<PrayerAppSettings> toggleFavorite(String prayerId) async {
    final settings = await getUserPreferences();

    final PrayerAppSettings updatedSettings;
    if (settings.favoritePrayerIds.contains(prayerId)) {
      updatedSettings = settings.removeFavorite(prayerId);
    } else {
      updatedSettings = settings.addFavorite(prayerId);
    }

    await saveUserPreferences(updatedSettings);
    return updatedSettings;
  }

  // Add prayer to recent (deprecated - use PrayerAppSettingsProvider instead)
  @Deprecated('Use PrayerAppSettingsProvider instead')
  Future<PrayerAppSettings> addToRecent(String prayerId) async {
    final settings = await getUserPreferences();
    final updatedSettings = settings.addToRecent(prayerId);
    await saveUserPreferences(updatedSettings);
    return updatedSettings;
  }

  // Search prayers
  Future<List<Prayer>> searchPrayers(String query) async {
    if (query.isEmpty) return [];

    final allPrayers = await getAllPrayers();
    final lowerQuery = query.toLowerCase();

    return allPrayers.where((prayer) {
      return prayer.title.toLowerCase().contains(lowerQuery) ||
          prayer.description.toLowerCase().contains(lowerQuery) ||
          prayer.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  // Get prayer category groups
  Future<List<PrayerCategoryGroup>> getPrayerCategoryGroups() async {
    return List.from(_categoryGroups)..sort((a, b) => a.order.compareTo(b.order));
  }

  // Get prayer categories
  Future<List<PrayerCategory>> getPrayerCategories() async {
    return List.from(_categories);
  }

  // Get prayers by category
  Future<List<Prayer>> getPrayersByCategory(String categoryId) async {
    final allPrayers = await getAllPrayers();
    return allPrayers.where((prayer) => prayer.categories.contains(categoryId)).toList();
  }

  // Get prayers by category group
  Future<List<Prayer>> getPrayersByGroup(String groupId) async {
    final allPrayers = await getAllPrayers();
    final categories = await getPrayerCategories();

    final categoryIds = categories
        .where((cat) => cat.groupId == groupId)
        .map((cat) => cat.id)
        .toSet();

    return allPrayers.where((prayer) =>
        prayer.categories.any((cat) => categoryIds.contains(cat))
    ).toList();
  }

  // Prayer of the Day method
  Future<Prayer?> getPrayerOfTheDay(DateTime date, String liturgicalSeason) async {
    final allPrayers = await getAllPrayers();
    final liturgicalPrayers = allPrayers.where((p) => p.isLiturgical).toList();

    // Sort by priority (higher first)
    liturgicalPrayers.sort((a, b) => b.liturgicalPriority.compareTo(a.liturgicalPriority));

    // Filter by season if specified
    final seasonalPrayers = liturgicalPrayers
        .where((p) => p.liturgicalSeason == liturgicalSeason || p.liturgicalSeason == null)
        .toList();

    if (seasonalPrayers.isEmpty) return liturgicalPrayers.isEmpty ? null : liturgicalPrayers.first;

    // Simple rotation based on day of year for variety
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
    return seasonalPrayers[dayOfYear % seasonalPrayers.length];
  }

  // Clear cache method for testing or refreshing
  void clearCache() {
    _cachedPrayers = null;
  }
}
