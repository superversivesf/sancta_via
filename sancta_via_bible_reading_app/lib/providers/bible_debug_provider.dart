import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bible_data_riverpod/bible_data_riverpod.dart' hide AppLogger;
import '../utils/logger.dart';

/// Provider to debug Bible data availability
final bibleDebugProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  AppLogger.debug('Starting Bible debug check...', 'DEBUG');

  final serviceAsync = ref.watch(bibleServiceNotifierProvider);

  return serviceAsync.when(
    data: (service) async {
      AppLogger.debug(
        'Bible service is available, checking translations...',
        'DEBUG',
      );

      final availableTranslations = await service.getAvailableTranslations();
      AppLogger.debug(
        'Available translations: ${availableTranslations.map((t) => t.id).join(', ')}',
        'DEBUG',
      );

      final stats = service.getCacheStats();
      AppLogger.debug('Cache stats: $stats', 'DEBUG');

      // Try to check if Mark exists and test actual data loading
      for (final translation in BibleTranslation.values) {
        AppLogger.debug(
          'Checking availability of ${translation.name}...',
          'DEBUG',
        );
        final isAvailable = await service.isTranslationAvailable(translation);
        AppLogger.debug('${translation.name} available: $isAvailable', 'DEBUG');

        // Try to get a simple scripture reference even if not available
        try {
          AppLogger.debug(
            'Attempting to load Mark 1:1 from ${translation.name}...',
            'DEBUG',
          );
          final testScripture = await service.getScriptureByReference(
            'Mark 1:1',
            translation,
          );
          AppLogger.debug(
            'Mark 1:1 result: found=${testScripture.found}, text="${testScripture.text}", error="${testScripture.errorMessage}"',
            'DEBUG',
          );
        } catch (e) {
          AppLogger.debug(
            'Exception loading Mark 1:1 from ${translation.name}: $e',
            'DEBUG',
          );
        }

        if (isAvailable) {
          AppLogger.debug(
            'Checking if Mark exists in ${translation.name}...',
            'DEBUG',
          );
          final hasMarkBook = await service.hasBook('Mark', translation);
          AppLogger.debug(
            'Mark book exists in ${translation.name}: $hasMarkBook',
            'DEBUG',
          );

          if (hasMarkBook) {
            AppLogger.debug(
              'Getting book names for ${translation.name}...',
              'DEBUG',
            );
            final bookNames = await service.getBookNames(translation);
            AppLogger.debug(
              'Books in ${translation.name}: ${bookNames.take(5).join(', ')}...',
              'DEBUG',
            );
          }
        }
      }

      return {
        'available_translations': availableTranslations
            .map((t) => t.id)
            .toList(),
        'cache_stats': stats,
      };
    },
    loading: () async {
      AppLogger.debug('Bible service is still loading...', 'DEBUG');
      return {'status': 'loading'};
    },
    error: (error, stack) async {
      AppLogger.debug('Bible service error: $error', 'DEBUG');
      AppLogger.debug('Stack trace: $stack', 'DEBUG');
      return {'error': error.toString()};
    },
  );
});
