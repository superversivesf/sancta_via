import '../models/novena.dart';
import '../../../utils/logger.dart';
import '../../../services/database/novena_database_service.dart';

/// Repository for accessing novena data from SQLite database
class NovenaRepository {
  final NovenaDatabaseService _databaseService = NovenaDatabaseService();

  /// Load novena metadata from database
  Future<List<NovenaMetadata>> loadNovenaMetadata() async {
    try {
      final results = await _databaseService.getAllNovenaMetadata();

      final metadata = results.map((data) {
        return NovenaMetadata(
          id: data['id'] as String,
          title: data['title'] as String,
          description: data['description'] as String,
          saint: data['saint'] as String,
          feastDay: data['feast_day'] as String,
          intentionCategory: data['intention_category'] as String,
          difficulty: data['difficulty'] as String,
          durationMinutes: data['duration_minutes'] as int,
        );
      }).toList();

      AppLogger.debug(
        'Loaded ${metadata.length} novena metadata records from database',
        'NOVENA_REPO',
      );
      return metadata;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to load novena metadata from database',
        e,
        stackTrace,
        'NOVENA_REPO',
      );
      throw Exception('Failed to load novena metadata: $e');
    }
  }

  /// Load a specific novena by ID from database
  Future<Novena> loadNovena(String novenaId) async {
    try {
      final novenaData = await _databaseService.getNovenaById(novenaId);

      if (novenaData == null) {
        // Try to get available IDs for better error message
        final metadata = await loadNovenaMetadata();
        final availableIds = metadata.map((meta) => meta.id).join(', ');
        AppLogger.error(
          'Novena not found: $novenaId. Available IDs: $availableIds',
          null,
          null,
          'NOVENA_REPO',
        );
        throw ArgumentError('Novena not found: $novenaId');
      }

      final novena = Novena.fromJson(novenaData);
      AppLogger.debug('Loaded novena "$novenaId" from database', 'NOVENA_REPO');
      return novena;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to load novena "$novenaId" from database',
        e,
        stackTrace,
        'NOVENA_REPO',
      );
      throw Exception('Failed to load novena $novenaId: $e');
    }
  }

  /// Get novenas by category
  Future<List<NovenaMetadata>> getNovenasByCategory(String category) async {
    try {
      final results = await _databaseService.getNovenasByCategory(category);

      final metadata = results.map((data) {
        return NovenaMetadata(
          id: data['id'] as String,
          title: data['title'] as String,
          description: data['description'] as String,
          saint: data['saint'] as String,
          feastDay: data['feast_day'] as String,
          intentionCategory: data['intention_category'] as String,
          difficulty: data['difficulty'] as String,
          durationMinutes: data['duration_minutes'] as int,
        );
      }).toList();

      AppLogger.debug(
        'Found ${metadata.length} novenas for category: $category',
        'NOVENA_REPO',
      );
      return metadata;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get novenas by category: $category',
        e,
        stackTrace,
        'NOVENA_REPO',
      );
      throw Exception('Failed to get novenas by category: $e');
    }
  }

  /// Get novenas by difficulty
  Future<List<NovenaMetadata>> getNovenasByDifficulty(String difficulty) async {
    try {
      final results = await _databaseService.getNovenasByDifficulty(difficulty);

      final metadata = results.map((data) {
        return NovenaMetadata(
          id: data['id'] as String,
          title: data['title'] as String,
          description: data['description'] as String,
          saint: data['saint'] as String,
          feastDay: data['feast_day'] as String,
          intentionCategory: data['intention_category'] as String,
          difficulty: data['difficulty'] as String,
          durationMinutes: data['duration_minutes'] as int,
        );
      }).toList();

      AppLogger.debug(
        'Found ${metadata.length} novenas for difficulty: $difficulty',
        'NOVENA_REPO',
      );
      return metadata;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get novenas by difficulty: $difficulty',
        e,
        stackTrace,
        'NOVENA_REPO',
      );
      throw Exception('Failed to get novenas by difficulty: $e');
    }
  }

  /// Search novenas by text
  Future<List<NovenaMetadata>> searchNovenas(String searchTerm) async {
    try {
      final results = await _databaseService.searchNovenas(searchTerm);

      final metadata = results.map((data) {
        return NovenaMetadata(
          id: data['id'] as String,
          title: data['title'] as String,
          description: data['description'] as String,
          saint: data['saint'] as String,
          feastDay: data['feast_day'] as String,
          intentionCategory: data['intention_category'] as String,
          difficulty: data['difficulty'] as String,
          durationMinutes: data['duration_minutes'] as int,
        );
      }).toList();

      AppLogger.debug(
        'Found ${metadata.length} novenas matching: $searchTerm',
        'NOVENA_REPO',
      );
      return metadata;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to search novenas: $searchTerm',
        e,
        stackTrace,
        'NOVENA_REPO',
      );
      throw Exception('Failed to search novenas: $e');
    }
  }

  /// Get all available categories
  Future<List<String>> getAllCategories() async {
    try {
      final categories = await _databaseService.getAllCategories();
      AppLogger.debug(
        'Retrieved ${categories.length} categories from database',
        'NOVENA_REPO',
      );
      return categories;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get categories from database',
        e,
        stackTrace,
        'NOVENA_REPO',
      );
      throw Exception('Failed to get categories: $e');
    }
  }

  /// Get all available difficulties
  Future<List<String>> getAllDifficulties() async {
    try {
      final difficulties = await _databaseService.getAllDifficulties();
      AppLogger.debug(
        'Retrieved ${difficulties.length} difficulties from database',
        'NOVENA_REPO',
      );
      return difficulties;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get difficulties from database',
        e,
        stackTrace,
        'NOVENA_REPO',
      );
      throw Exception('Failed to get difficulties: $e');
    }
  }

  /// Get database statistics (useful for debugging)
  Future<Map<String, int>> getDatabaseStats() async {
    try {
      return await _databaseService.getDatabaseStats();
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get database stats',
        e,
        stackTrace,
        'NOVENA_REPO',
      );
      return {'error': 1};
    }
  }
}
