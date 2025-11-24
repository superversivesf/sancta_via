import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/novena.dart';
import '../repositories/novena_repository.dart';
import 'novena_state_provider.dart';
import '../../../services/date_change_service.dart';
import '../../../utils/logger.dart';

// Repository provider
final novenaRepositoryProvider = Provider<NovenaRepository>((ref) {
  return NovenaRepository();
});

// Novena metadata list provider
final novenaMetadataListProvider = FutureProvider<List<NovenaMetadata>>((ref) async {
  final repository = ref.read(novenaRepositoryProvider);
  return repository.loadNovenaMetadata();
});

// Individual novena provider by ID
final novenaByIdProvider = FutureProvider.family<Novena?, String>((ref, novenaId) async {
  final repository = ref.read(novenaRepositoryProvider);
  try {
    return await repository.loadNovena(novenaId);
  } catch (e) {
    AppLogger.error('Failed to load novena "$novenaId"', e, null, 'NOVENA_PROVIDER');
    return null;
  }
});

// Current spiritual day of active novena provider
final currentNovenaDayProvider = FutureProvider<NovenaDay?>((ref) async {
  // Watch date changes to refresh current day calculation
  ref.watch(currentDateProvider);
  final activeNovena = ref.watch(novenaStateProvider);
  if (activeNovena == null) return null;

  final repository = ref.read(novenaRepositoryProvider);
  try {
    final novena = await repository.loadNovena(activeNovena.novenaId);
    final spiritualDay = activeNovena.spiritualDay;
    
    if (spiritualDay > 0 && spiritualDay <= novena.days.length) {
      return novena.days[spiritualDay - 1];
    }
    return null;
  } catch (e) {
    return null;
  }
});

// Enhanced database-powered providers

// All available categories provider
final novenasCategoriesProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.read(novenaRepositoryProvider);
  try {
    return await repository.getAllCategories();
  } catch (e) {
    AppLogger.error('Failed to load novena categories', e, null, 'NOVENA_PROVIDER');
    return [];
  }
});

// All available difficulties provider
final novenasDifficultiesProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.read(novenaRepositoryProvider);
  try {
    return await repository.getAllDifficulties();
  } catch (e) {
    AppLogger.error('Failed to load novena difficulties', e, null, 'NOVENA_PROVIDER');
    return [];
  }
});

// Novenas by category provider
final novenasByCategoryProvider = FutureProvider.family<List<NovenaMetadata>, String>((ref, category) async {
  final repository = ref.read(novenaRepositoryProvider);
  try {
    return await repository.getNovenasByCategory(category);
  } catch (e) {
    AppLogger.error('Failed to load novenas for category "$category"', e, null, 'NOVENA_PROVIDER');
    return [];
  }
});

// Novenas by difficulty provider
final novenasByDifficultyProvider = FutureProvider.family<List<NovenaMetadata>, String>((ref, difficulty) async {
  final repository = ref.read(novenaRepositoryProvider);
  try {
    return await repository.getNovenasByDifficulty(difficulty);
  } catch (e) {
    AppLogger.error('Failed to load novenas for difficulty "$difficulty"', e, null, 'NOVENA_PROVIDER');
    return [];
  }
});

// Search novenas provider
final novenaSearchProvider = FutureProvider.family<List<NovenaMetadata>, String>((ref, searchTerm) async {
  if (searchTerm.trim().isEmpty) {
    // Return all novenas if search term is empty
    return ref.read(novenaMetadataListProvider.future);
  }
  
  final repository = ref.read(novenaRepositoryProvider);
  try {
    return await repository.searchNovenas(searchTerm);
  } catch (e) {
    AppLogger.error('Failed to search novenas for "$searchTerm"', e, null, 'NOVENA_PROVIDER');
    return [];
  }
});

// Database statistics provider (useful for debugging/admin)
final databaseStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.read(novenaRepositoryProvider);
  try {
    return await repository.getDatabaseStats();
  } catch (e) {
    AppLogger.error('Failed to get database stats', e, null, 'NOVENA_PROVIDER');
    return {'error': 1};
  }
});

// State providers for filtering/search UI

// Current selected category filter (for UI state)
final selectedCategoryFilterProvider = StateProvider<String?>((ref) => null);

// Current selected difficulty filter (for UI state)  
final selectedDifficultyFilterProvider = StateProvider<String?>((ref) => null);

// Current search term (for UI state)
final searchTermProvider = StateProvider<String>((ref) => '');

// Filtered novenas provider (combines search and filters)
final filteredNovenaMetadataProvider = FutureProvider<List<NovenaMetadata>>((ref) async {
  final searchTerm = ref.watch(searchTermProvider);
  final selectedCategory = ref.watch(selectedCategoryFilterProvider);
  final selectedDifficulty = ref.watch(selectedDifficultyFilterProvider);
  
  // If no filters applied, return all novenas
  if (searchTerm.trim().isEmpty && selectedCategory == null && selectedDifficulty == null) {
    return ref.read(novenaMetadataListProvider.future);
  }
  
  List<NovenaMetadata> results;
  
  // Start with search results if there's a search term
  if (searchTerm.trim().isNotEmpty) {
    results = await ref.read(novenaSearchProvider(searchTerm).future);
  } else {
    results = await ref.read(novenaMetadataListProvider.future);
  }
  
  // Apply category filter
  if (selectedCategory != null) {
    results = results.where((novena) => novena.intentionCategory == selectedCategory).toList();
  }
  
  // Apply difficulty filter
  if (selectedDifficulty != null) {
    results = results.where((novena) => novena.difficulty == selectedDifficulty).toList();
  }
  
  AppLogger.debug('Filtered novenas: ${results.length} results for search="$searchTerm", category=$selectedCategory, difficulty=$selectedDifficulty', 'NOVENA_PROVIDER');
  return results;
});
