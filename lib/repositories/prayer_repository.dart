import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/prayer_database.dart';
import '../database/database_migration_service.dart';
import '../models/prayer.dart';
import '../models/prayer_category.dart';
import '../models/prayer_category_group.dart';
import '../models/prayer_app_settings.dart';
import '../utils/logger.dart';

// Create a logger instance for consistency
final logger = AppLogger;

/// Repository for prayer data access using SQLite database
/// Maintains the same API as the previous JSON-based implementation
class PrayerRepository {
  static const String _preferencesKey = 'prayer_preferences';

  // Singleton pattern for database connection
  static PrayerDatabase get _database => PrayerDatabase.instance;

  // Cache for loaded prayers to improve performance
  List<Prayer>? _cachedPrayers;
  List<PrayerCategory>? _cachedCategories;
  List<PrayerCategoryGroup>? _cachedCategoryGroups;
  
  // Flag to track if migration has been attempted
  bool _migrationChecked = false;

  /// Ensure database migration is complete before any data access
  Future<void> _ensureMigrationComplete() async {
    if (_migrationChecked) return;
    
    try {
      AppLogger.info('Checking database migration status...');
      
      // Check if migration is needed
      if (await DatabaseMigrationService.isMigrationNeeded()) {
        AppLogger.info('Database migration required, starting migration...');
        await DatabaseMigrationService.migrateJsonToDatabase();
        AppLogger.info('Database migration completed successfully');
      } else {
        AppLogger.info('Database already populated, skipping migration');
      }
      
      _migrationChecked = true;
    } catch (e) {
      AppLogger.error('Database migration failed', e, null, 'MIGRATION');
      // Still mark as checked to avoid infinite retry loops
      _migrationChecked = true;
      rethrow;
    }
  }

  /// Get all prayers from database
  Future<List<Prayer>> getAllPrayers() async {
    // Return cached data if available
    if (_cachedPrayers != null) {
      return _cachedPrayers!;
    }

    try {
      await _ensureMigrationComplete();
      
      final prayers = await _database.getAllPrayers();
      
      // Cache the result for future calls
      _cachedPrayers = prayers;
      
      AppLogger.info('Loaded ${prayers.length} prayers from database', 'REPO');
      return prayers;
    } catch (e) {
      AppLogger.error('Error loading prayers from database', e, null, 'REPO');
      return [];
    }
  }

  /// Get prayer by ID from database
  Future<Prayer?> getPrayer(String prayerId) async {
    try {
      await _ensureMigrationComplete();
      
      // Try to get from cache first
      if (_cachedPrayers != null) {
        try {
          return _cachedPrayers!.firstWhere((prayer) => prayer.id == prayerId);
        } catch (e) {
          // Prayer not found in cache, fall through to database query
        }
      }
      
      // Query database directly
      final prayer = await _database.getPrayerById(prayerId);
      
      if (prayer == null) {
        AppLogger.warning('Prayer not found: $prayerId', 'REPO');
      }
      
      return prayer;
    } catch (e) {
      AppLogger.error('Error loading prayer $prayerId', e, null, 'REPO');
      return null;
    }
  }

  /// Search prayers by title, description, or tags
  Future<List<Prayer>> searchPrayers(String query) async {
    if (query.isEmpty) return [];

    try {
      await _ensureMigrationComplete();
      
      final results = await _database.searchPrayers(query);
      
      AppLogger.info('Found ${results.length} prayers matching "$query"', 'REPO');
      return results;
    } catch (e) {
      AppLogger.error('Error searching prayers for "$query"', e, null, 'REPO');
      return [];
    }
  }

  /// Get prayer category groups from database
  Future<List<PrayerCategoryGroup>> getPrayerCategoryGroups() async {
    // Return cached data if available
    if (_cachedCategoryGroups != null) {
      return _cachedCategoryGroups!;
    }

    try {
      await _ensureMigrationComplete();
      
      final groups = await _database.getCategoryGroups();
      
      // Cache the result
      _cachedCategoryGroups = groups;
      
      AppLogger.info('Loaded ${groups.length} category groups from database', 'REPO');
      return groups;
    } catch (e) {
      AppLogger.error('Error loading category groups from database', e, null, 'REPO');
      return [];
    }
  }

  /// Get prayer categories from database
  Future<List<PrayerCategory>> getPrayerCategories() async {
    // Return cached data if available
    if (_cachedCategories != null) {
      return _cachedCategories!;
    }

    try {
      await _ensureMigrationComplete();
      
      final categories = await _database.getCategories();
      
      // Cache the result
      _cachedCategories = categories;
      
      AppLogger.info('Loaded ${categories.length} categories from database', 'REPO');
      return categories;
    } catch (e) {
      AppLogger.error('Error loading categories from database', e, null, 'REPO');
      return [];
    }
  }

  /// Get prayers by category from database
  Future<List<Prayer>> getPrayersByCategory(String categoryId) async {
    try {
      await _ensureMigrationComplete();
      
      final prayers = await _database.getPrayersByCategory(categoryId);
      
      AppLogger.info('Found ${prayers.length} prayers in category "$categoryId"', 'REPO');
      return prayers;
    } catch (e) {
      AppLogger.error('Error loading prayers for category $categoryId', e, null, 'REPO');
      return [];
    }
  }

  /// Get prayers by category group
  Future<List<Prayer>> getPrayersByGroup(String groupId) async {
    try {
      await _ensureMigrationComplete();
      
      // Get all categories in this group
      final allCategories = await getPrayerCategories();
      final categoryIds = allCategories
          .where((cat) => cat.groupId == groupId)
          .map((cat) => cat.id)
          .toList();

      // Get prayers for all categories in the group
      final Set<Prayer> groupPrayers = {};
      for (final categoryId in categoryIds) {
        final categoryPrayers = await getPrayersByCategory(categoryId);
        groupPrayers.addAll(categoryPrayers);
      }

      final result = groupPrayers.toList();
      AppLogger.info('Found ${result.length} prayers in group "$groupId"', 'REPO');
      return result;
    } catch (e) {
      AppLogger.error('Error loading prayers for group $groupId', e, null, 'REPO');
      return [];
    }
  }

  /// Get Prayer of the Day based on liturgical calendar
  Future<Prayer?> getPrayerOfTheDay(DateTime date, String liturgicalSeason) async {
    try {
      await _ensureMigrationComplete();
      
      // Get liturgical prayers filtered by season
      final liturgicalPrayers = await _database.getLiturgicalPrayers(season: liturgicalSeason);
      
      if (liturgicalPrayers.isEmpty) {
        // Fallback to any liturgical prayers if none for specific season
        final allLiturgicalPrayers = await _database.getLiturgicalPrayers();
        if (allLiturgicalPrayers.isEmpty) return null;
        
        // Simple rotation based on day of year for variety
        final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
        return allLiturgicalPrayers[dayOfYear % allLiturgicalPrayers.length];
      }

      // Simple rotation based on day of year for variety
      final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
      final selectedPrayer = liturgicalPrayers[dayOfYear % liturgicalPrayers.length];
      
      AppLogger.info('Selected prayer of the day: ${selectedPrayer.title} for season: $liturgicalSeason', 'REPO');
      return selectedPrayer;
    } catch (e) {
      AppLogger.error('Error getting prayer of the day', e, null, 'REPO');
      return null;
    }
  }

  /// Clear all caches to force fresh data from database
  void clearCache() {
    _cachedPrayers = null;
    _cachedCategories = null;
    _cachedCategoryGroups = null;
    AppLogger.info('Prayer repository cache cleared', 'REPO');
  }

  /// Force database re-migration (useful for testing or data updates)
  Future<void> forceMigration() async {
    try {
      AppLogger.info('Forcing database re-migration...', 'REPO');
      
      // Clear caches
      clearCache();
      
      // Reset migration flag
      _migrationChecked = false;
      
      // Force re-migration
      await DatabaseMigrationService.forceMigration();
      
      AppLogger.info('Forced migration completed successfully', 'REPO');
    } catch (e) {
      AppLogger.error('Error during forced migration', e, null, 'REPO');
      rethrow;
    }
  }

  /// Get migration status for debugging
  Future<Map<String, dynamic>> getMigrationStatus() async {
    try {
      return await DatabaseMigrationService.getMigrationStatus();
    } catch (e) {
      AppLogger.error('Error getting migration status', e, null, 'REPO');
      return {
        'isComplete': false,
        'message': 'Error checking migration status: $e',
      };
    }
  }

  // =============================================================================
  // DEPRECATED METHODS - These maintain backward compatibility but should not be used
  // Use PrayerAppSettingsProvider instead for preferences management
  // =============================================================================

  /// Get user preferences (deprecated - use PrayerAppSettingsProvider instead)
  @Deprecated('Use PrayerAppSettingsProvider instead')
  Future<PrayerAppSettings> getUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_preferencesKey);

    if (jsonString == null) {
      return PrayerAppSettings.defaults();
    }

    return PrayerAppSettings.fromJson(json.decode(jsonString));
  }

  /// Save user preferences (deprecated - use PrayerAppSettingsProvider instead)
  @Deprecated('Use PrayerAppSettingsProvider instead')
  Future<void> saveUserPreferences(PrayerAppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferencesKey, json.encode(settings.toJson()));
  }

  /// Toggle favorite status (deprecated - use PrayerAppSettingsProvider instead)
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

  /// Add prayer to recent (deprecated - use PrayerAppSettingsProvider instead)
  @Deprecated('Use PrayerAppSettingsProvider instead')
  Future<PrayerAppSettings> addToRecent(String prayerId) async {
    final settings = await getUserPreferences();
    final updatedSettings = settings.addToRecent(prayerId);
    await saveUserPreferences(updatedSettings);
    return updatedSettings;
  }
}
