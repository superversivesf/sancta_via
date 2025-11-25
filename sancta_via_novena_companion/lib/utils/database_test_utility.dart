import '../../../services/database/novena_database_service.dart';
import '../../../services/database/novena_database_initializer.dart';
import '../../../utils/logger.dart';

/// Utility class for testing and debugging the novena database
class DatabaseTestUtility {
  static final NovenaDatabaseService _databaseService = NovenaDatabaseService();
  static final NovenaDatabaseInitializer _initializer =
      NovenaDatabaseInitializer();

  /// Run a comprehensive test of the database
  static Future<Map<String, dynamic>> runDatabaseTest() async {
    final results = <String, dynamic>{};

    try {
      AppLogger.info('Starting database test...', 'DB_TEST');

      // Test 1: Database initialization
      final initResult = await _initializer.initializeDatabase();
      results['initialization'] = {
        'success': initResult.success,
        'novena_count': initResult.novenaCount,
        'was_already_initialized': initResult.wasAlreadyInitialized,
        'errors': initResult.errors,
      };

      if (!initResult.success && !initResult.wasAlreadyInitialized) {
        results['error'] = 'Database initialization failed';
        return results;
      }

      // Test 2: Get database stats
      final stats = await _databaseService.getDatabaseStats();
      results['stats'] = stats;

      // Test 3: Get all metadata
      final metadata = await _databaseService.getAllNovenaMetadata();
      results['metadata_count'] = metadata.length;
      results['sample_metadata'] = metadata
          .take(2)
          .map(
            (meta) => {
              'id': meta['id'],
              'title': meta['title'],
              'saint': meta['saint'],
            },
          )
          .toList();

      // Test 4: Get a specific novena
      if (metadata.isNotEmpty) {
        final firstNovenaId = metadata.first['id'] as String;
        final fullNovena = await _databaseService.getNovenaById(firstNovenaId);
        results['sample_novena'] = {
          'id': fullNovena?['id'],
          'title': fullNovena?['title'],
          'days_count': (fullNovena?['days'] as List?)?.length ?? 0,
        };
      }

      // Test 5: Get categories
      final categories = await _databaseService.getAllCategories();
      results['categories'] = categories;

      // Test 6: Get difficulties
      final difficulties = await _databaseService.getAllDifficulties();
      results['difficulties'] = difficulties;

      // Test 7: Search test
      final searchResults = await _databaseService.searchNovenas('St.');
      results['search_test'] = {
        'search_term': 'St.',
        'results_count': searchResults.length,
      };

      results['test_completed'] = true;
      AppLogger.info('Database test completed successfully', 'DB_TEST');
    } catch (e, stackTrace) {
      results['test_completed'] = false;
      results['error'] = e.toString();
      AppLogger.error('Database test failed', e, stackTrace, 'DB_TEST');
    }

    return results;
  }

  /// Print database info to console (useful for debugging)
  static Future<void> printDatabaseInfo() async {
    try {
      final info = await _initializer.getDatabaseInfo();

      print('\n=== NOVENA DATABASE INFO ===');
      print('Initialized: ${info['initialized']}');

      if (info.containsKey('stats')) {
        final stats = info['stats'] as Map<String, int>;
        print('Novenas: ${stats['novenas']}');
        print('Days: ${stats['days']}');
      }

      if (info.containsKey('categories')) {
        final categories = info['categories'] as List<String>;
        print('Categories: ${categories.join(', ')}');
      }

      if (info.containsKey('difficulties')) {
        final difficulties = info['difficulties'] as List<String>;
        print('Difficulties: ${difficulties.join(', ')}');
      }

      if (info.containsKey('error')) {
        print('Error: ${info['error']}');
      }

      print('===========================\n');
    } catch (e) {
      print('Failed to get database info: $e');
    }
  }

  /// Reset and reinitialize database (useful for testing)
  static Future<bool> resetDatabase() async {
    try {
      AppLogger.warning('Resetting database...', 'DB_TEST');

      final result = await _initializer.reinitializeDatabase();

      if (result.success) {
        AppLogger.info('Database reset successful', 'DB_TEST');
        return true;
      } else {
        AppLogger.error('Database reset failed: ${result.error}', 'DB_TEST');
        return false;
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Database reset threw exception',
        e,
        stackTrace,
        'DB_TEST',
      );
      return false;
    }
  }
}
