import 'dart:convert';
import 'package:flutter/services.dart';
import '../../../utils/logger.dart';
import 'novena_database_service.dart';

/// Service to initialize the novena database from JSON assets
class NovenaDatabaseInitializer {
  static final NovenaDatabaseInitializer _instance = NovenaDatabaseInitializer._internal();
  factory NovenaDatabaseInitializer() => _instance;
  NovenaDatabaseInitializer._internal();

  final NovenaDatabaseService _databaseService = NovenaDatabaseService();
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialize database and populate from JSON files if empty
  Future<DatabaseInitResult> initializeDatabase() async {
    try {
      AppLogger.info('Starting database initialization...', 'DB_INIT');
      
      // Check if database is already populated
      final isEmpty = await _databaseService.isDatabaseEmpty();
      
      if (!isEmpty) {
        AppLogger.info('Database already contains data, skipping initialization', 'DB_INIT');
        _isInitialized = true;
        return DatabaseInitResult.alreadyInitialized();
      }
      
      // Database is empty, populate from JSON files
      final result = await _populateFromAssets();
      
      if (result.success) {
        _isInitialized = true;
        AppLogger.info('Database initialization completed successfully', 'DB_INIT');
      } else {
        AppLogger.error('Database initialization failed', result.error, null, 'DB_INIT');
      }
      
      return result;
      
    } catch (e, stackTrace) {
      AppLogger.error('Database initialization failed', e, stackTrace, 'DB_INIT');
      return DatabaseInitResult.failure('Database initialization failed: $e');
    }
  }

  /// Populate database from JSON assets
  Future<DatabaseInitResult> _populateFromAssets() async {
    try {
      AppLogger.debug('Reading novena metadata and JSON files from assets...', 'DB_INIT');
      
      // First, load the metadata file
      final metadataString = await rootBundle.loadString('assets/novenas/novenas_metadata.json');
      final metadataJson = json.decode(metadataString) as Map<String, dynamic>;
      final novenasList = metadataJson['novenas'] as List<dynamic>;
      
      AppLogger.debug('Loaded metadata for ${novenasList.length} novenas', 'DB_INIT');
      
      int successCount = 0;
      final errors = <String>[];
      
      // Load and merge each novena with its metadata
      for (final metadataEntry in novenasList) {
        final metadata = metadataEntry as Map<String, dynamic>;
        final fileName = metadata['file_name'] as String;
        
        try {
          // Load the full novena content
          final novenaContent = await _loadNovenaFromAsset(fileName);
          if (novenaContent != null) {
            // Merge metadata with content
            final completeNovena = _mergeNovenaData(metadata, novenaContent);
            
            // Validate the complete novena
            if (_validateNovenaData(completeNovena)) {
              await _databaseService.insertNovena(completeNovena);
              successCount++;
              AppLogger.debug('Successfully imported: ${completeNovena['id']}', 'DB_INIT');
            } else {
              errors.add('Failed to validate merged data for $fileName');
            }
          } else {
            errors.add('Failed to load content for $fileName');
          }
        } catch (e) {
          errors.add('Failed to process $fileName: $e');
          AppLogger.error('Failed to process $fileName', e, null, 'DB_INIT');
        }
      }
      
      // Return result
      if (successCount == 0) {
        return DatabaseInitResult.failure('No novenas could be imported');
      } else if (errors.isNotEmpty) {
        return DatabaseInitResult.partial(successCount, errors);
      } else {
        return DatabaseInitResult.success(successCount);
      }
      
    } catch (e, stackTrace) {
      AppLogger.error('Failed to populate database from assets', e, stackTrace, 'DB_INIT');
      return DatabaseInitResult.failure('Failed to read asset files: $e');
    }
  }

  /// Merge metadata with novena content to create complete novena object
  Map<String, dynamic> _mergeNovenaData(Map<String, dynamic> metadata, Map<String, dynamic> content) {
    // Start with the content (which has the full prayer structure)
    final merged = Map<String, dynamic>.from(content);
    
    // Add metadata fields that are missing
    merged['intention_category'] = metadata['intention_category'];
    merged['difficulty'] = metadata['difficulty'];
    merged['duration_minutes'] = metadata['duration_minutes'];
    
    // Ensure description from metadata is used (more detailed)
    if (metadata.containsKey('description') && metadata['description'] != null) {
      merged['description'] = metadata['description'];
    }
    
    AppLogger.debug('Merged novena data for: ${merged['id']}', 'DB_INIT');
    return merged;
  }

  /// Load a single novena from asset bundle
  Future<Map<String, dynamic>?> _loadNovenaFromAsset(String fileName) async {
    try {
      AppLogger.debug('Loading novena from asset: $fileName', 'DB_INIT');
      
      final assetPath = 'assets/novenas/$fileName';
      final jsonString = await rootBundle.loadString(assetPath);
      final Map<String, dynamic> novenaData = json.decode(jsonString);
      
      AppLogger.debug('Successfully loaded novena content: ${novenaData['id']}', 'DB_INIT');
      return novenaData;
      
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load $fileName', e, stackTrace, 'DB_INIT');
      return null;
    }
  }

  /// Validate that novena data has all required fields
  bool _validateNovenaData(Map<String, dynamic> data) {
    const requiredFields = [
      'id', 'title', 'description', 'saint', 'feast_day',
      'intention_category', 'difficulty', 'duration_minutes',
      'intention', 'instructions', 'source', 'days'
    ];
    
    // Check top-level fields
    for (final field in requiredFields) {
      if (!data.containsKey(field) || data[field] == null) {
        AppLogger.warning('Missing required field: $field in ${data['id'] ?? 'unknown'}', 'DB_INIT');
        return false;
      }
    }
    
    // Validate days array
    final days = data['days'];
    if (days is! List || days.length != 9) {
      AppLogger.warning('Invalid days array: must be list of 9 items in ${data['id']}', 'DB_INIT');
      return false;
    }
    
    // Validate each day
    const requiredDayFields = [
      'day', 'title', 'opening_prayer', 'daily_prayer',
      'closing_prayer', 'reflection', 'intention_prayer'
    ];
    
    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      if (day is! Map<String, dynamic>) {
        AppLogger.warning('Day ${i + 1} is not a valid object in ${data['id']}', 'DB_INIT');
        return false;
      }
      
      for (final field in requiredDayFields) {
        if (!day.containsKey(field) || day[field] == null) {
          AppLogger.warning('Day ${i + 1} missing required field: $field in ${data['id']}', 'DB_INIT');
          return false;
        }
      }
      
      // Validate day number
      if (day['day'] != (i + 1)) {
        AppLogger.warning('Day ${i + 1} has incorrect day number: ${day['day']} in ${data['id']}', 'DB_INIT');
        return false;
      }
    }
    
    AppLogger.debug('Validation successful for novena: ${data['id']}', 'DB_INIT');
    return true;
  }

  /// Force reinitialize database (clears existing data)
  Future<DatabaseInitResult> reinitializeDatabase() async {
    try {
      AppLogger.warning('Force reinitializing database...', 'DB_INIT');
      
      // Clear existing data
      await _databaseService.clearAllData();
      
      // Reset initialization flag
      _isInitialized = false;
      
      // Repopulate from assets
      return await initializeDatabase();
      
    } catch (e, stackTrace) {
      AppLogger.error('Failed to reinitialize database', e, stackTrace, 'DB_INIT');
      return DatabaseInitResult.failure('Reinitialization failed: $e');
    }
  }

  /// Get database statistics after initialization
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    try {
      final stats = await _databaseService.getDatabaseStats();
      final categories = await _databaseService.getAllCategories();
      final difficulties = await _databaseService.getAllDifficulties();
      
      return {
        'initialized': _isInitialized,
        'stats': stats,
        'categories': categories,
        'difficulties': difficulties,
      };
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get database info', e, stackTrace, 'DB_INIT');
      return {
        'initialized': _isInitialized,
        'error': e.toString(),
      };
    }
  }
}

/// Result class for database initialization
class DatabaseInitResult {
  final bool success;
  final int novenaCount;
  final String? error;
  final List<String> errors;
  final bool wasAlreadyInitialized;

  DatabaseInitResult._({
    required this.success,
    required this.novenaCount,
    this.error,
    this.errors = const [],
    this.wasAlreadyInitialized = false,
  });

  factory DatabaseInitResult.success(int count) =>
      DatabaseInitResult._(success: true, novenaCount: count);

  factory DatabaseInitResult.failure(String error) =>
      DatabaseInitResult._(success: false, novenaCount: 0, error: error);

  factory DatabaseInitResult.partial(int count, List<String> errors) =>
      DatabaseInitResult._(success: true, novenaCount: count, errors: errors);

  factory DatabaseInitResult.alreadyInitialized() =>
      DatabaseInitResult._(success: true, novenaCount: 0, wasAlreadyInitialized: true);

  @override
  String toString() {
    if (wasAlreadyInitialized) return 'Already initialized';
    if (!success) return 'Failed: $error';
    if (errors.isNotEmpty) return 'Partial success: $novenaCount imported, ${errors.length} errors';
    return 'Success: $novenaCount novenas imported';
  }
}
