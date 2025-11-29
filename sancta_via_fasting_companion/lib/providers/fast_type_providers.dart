import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fast_type.dart';
import '../models/fast_type_category.dart';
import '../repositories/fasting_repository.dart';

/// Provider for the fasting repository
final fastingRepositoryProvider = Provider<FastingRepository>((ref) {
  return FastingRepository.instance;
});

/// Provider for all fast types
final allFastTypesProvider = FutureProvider<List<FastType>>((ref) async {
  final repository = ref.watch(fastingRepositoryProvider);
  return repository.getAllFastTypes();
});

/// Provider for fast types filtered by category
final fastTypesByCategoryProvider =
    FutureProvider.family<List<FastType>, FastTypeCategory>(
  (ref, category) async {
    final repository = ref.watch(fastingRepositoryProvider);
    return repository.getFastTypesByCategory(category);
  },
);

/// Provider for a specific fast type by ID
final fastTypeByIdProvider =
    FutureProvider.family<FastType?, String>((ref, id) async {
  final repository = ref.watch(fastingRepositoryProvider);
  return repository.getFastTypeById(id);
});

/// Provider for intermittent fast types (16:8, 18:6, etc.)
final intermittentFastTypesProvider = FutureProvider<List<FastType>>((ref) {
  return ref.watch(
    fastTypesByCategoryProvider(FastTypeCategory.intermittent).future,
  );
});

/// Provider for daily 24-hour fast types
final daily24hrFastTypesProvider = FutureProvider<List<FastType>>((ref) {
  return ref.watch(
    fastTypesByCategoryProvider(FastTypeCategory.daily24hr).future,
  );
});

/// Provider for liturgical fast types (Lent, Ash Wednesday, Good Friday)
final liturgicalFastTypesProvider = FutureProvider<List<FastType>>((ref) {
  return ref.watch(
    fastTypesByCategoryProvider(FastTypeCategory.liturgical).future,
  );
});

/// Provider for multi-day fast types
final multiDayFastTypesProvider = FutureProvider<List<FastType>>((ref) {
  return ref.watch(
    fastTypesByCategoryProvider(FastTypeCategory.multiDay).future,
  );
});
