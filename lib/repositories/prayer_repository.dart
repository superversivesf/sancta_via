import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/prayer.dart';
import '../models/prayer_category.dart';
import '../models/prayer_category_group.dart';
import '../models/prayer_metadata.dart';
import '../models/prayer_app_settings.dart';
import '../utils/logger.dart';

class PrayerRepository {
  static const String _prayersFolder = 'prayers';
  static const String _metadataFileName = 'prayers_metadata.json';
  static const String _preferencesKey = 'prayer_preferences';

  // Get all prayer metadata
  Future<List<PrayerMetadata>> getPrayerMetadata() async {
    try {
      final jsonString = await rootBundle.loadString('assets/$_prayersFolder/$_metadataFileName');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> prayersJson = jsonData['prayers'];

      return prayersJson.map((json) => PrayerMetadata.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('Error loading prayer metadata', e, null, 'PRAYER');
      return [];
    }
  }

  // Get prayer by ID
  Future<Prayer?> getPrayer(String prayerId) async {
    try {
      // First find the prayer metadata
      final allPrayers = await getPrayerMetadata();
      final metadata = allPrayers.firstWhere((prayer) => prayer.id == prayerId);

      // Load the prayer content
      final jsonString = await rootBundle.loadString('assets/$_prayersFolder/${metadata.fileName}');
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      return Prayer.fromJson(jsonData);
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
  Future<List<PrayerMetadata>> searchPrayers(String query) async {
    if (query.isEmpty) return [];

    final allPrayers = await getPrayerMetadata();
    final lowerQuery = query.toLowerCase();

    return allPrayers.where((prayer) {
      return prayer.title.toLowerCase().contains(lowerQuery) ||
          prayer.description.toLowerCase().contains(lowerQuery) ||
          prayer.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  // Get prayer category groups
  Future<List<PrayerCategoryGroup>> getPrayerCategoryGroups() async {
    try {
      final jsonString = await rootBundle.loadString('assets/$_prayersFolder/$_metadataFileName');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> groupsJson = jsonData['categoryGroups'];

      return groupsJson.map((json) => PrayerCategoryGroup.fromJson(json)).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
    } catch (e) {
      AppLogger.error('Error loading prayer category groups', e, null, 'PRAYER');
      return [];
    }
  }

  // Get prayer categories
  Future<List<PrayerCategory>> getPrayerCategories() async {
    try {
      final jsonString = await rootBundle.loadString('assets/$_prayersFolder/$_metadataFileName');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> categoriesJson = jsonData['categories'];

      return categoriesJson.map((json) => PrayerCategory.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('Error loading prayer categories', e, null, 'PRAYER');
      return [];
    }
  }

  // Get prayers by category
  Future<List<PrayerMetadata>> getPrayersByCategory(String categoryId) async {
    final allPrayers = await getPrayerMetadata();
    return allPrayers.where((prayer) => prayer.categories.contains(categoryId)).toList();
  }

  // Get prayers by category group
  Future<List<PrayerMetadata>> getPrayersByGroup(String groupId) async {
    final allPrayers = await getPrayerMetadata();
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
  Future<PrayerMetadata?> getPrayerOfTheDay(DateTime date, String liturgicalSeason) async {
    final allPrayers = await getPrayerMetadata();
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
}