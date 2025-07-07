import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bible_data_riverpod/bible_data_riverpod.dart';

/// Debug logging utility
void debugLog(String message, [String? tag]) {
  final timestamp = DateTime.now().toIso8601String();
  // ignore: avoid_print
  print('[$timestamp] ${tag != null ? '[$tag] ' : ''}$message');
}

/// Provider to debug Bible data availability
final bibleDebugProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  debugLog('Starting Bible debug check...', 'DEBUG');
  
  final serviceAsync = ref.watch(bibleServiceNotifierProvider);
  
  return serviceAsync.when(
    data: (service) async {
      debugLog('Bible service is available, checking translations...', 'DEBUG');
      
      final availableTranslations = await service.getAvailableTranslations();
      debugLog('Available translations: ${availableTranslations.map((t) => t.id).join(', ')}', 'DEBUG');
      
      final stats = service.getCacheStats();
      debugLog('Cache stats: $stats', 'DEBUG');
      
      // Try to check if Mark exists and test actual data loading
      for (final translation in BibleTranslation.values) {
        debugLog('Checking availability of ${translation.name}...', 'DEBUG');
        final isAvailable = await service.isTranslationAvailable(translation);
        debugLog('${translation.name} available: $isAvailable', 'DEBUG');
        
        // Try to get a simple scripture reference even if not available
        try {
          debugLog('Attempting to load Mark 1:1 from ${translation.name}...', 'DEBUG');
          final testScripture = await service.getScriptureByReference('Mark 1:1', translation);
          debugLog('Mark 1:1 result: found=${testScripture.found}, text="${testScripture.text}", error="${testScripture.errorMessage}"', 'DEBUG');
        } catch (e) {
          debugLog('Exception loading Mark 1:1 from ${translation.name}: $e', 'DEBUG');
        }
        
        if (isAvailable) {
          debugLog('Checking if Mark exists in ${translation.name}...', 'DEBUG');
          final hasMarkBook = await service.hasBook('Mark', translation);
          debugLog('Mark book exists in ${translation.name}: $hasMarkBook', 'DEBUG');
          
          if (hasMarkBook) {
            debugLog('Getting book names for ${translation.name}...', 'DEBUG');
            final bookNames = await service.getBookNames(translation);
            debugLog('Books in ${translation.name}: ${bookNames.take(5).join(', ')}...', 'DEBUG');
          }
        }
      }
      
      return {
        'available_translations': availableTranslations.map((t) => t.id).toList(),
        'cache_stats': stats,
      };
    },
    loading: () async {
      debugLog('Bible service is still loading...', 'DEBUG');
      return {'status': 'loading'};
    },
    error: (error, stack) async {
      debugLog('Bible service error: $error', 'DEBUG');
      debugLog('Stack trace: $stack', 'DEBUG');
      return {'error': error.toString()};
    },
  );
});
