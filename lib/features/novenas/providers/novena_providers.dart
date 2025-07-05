import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/novena.dart';
import '../repositories/novena_repository.dart';
import 'novena_state_provider.dart';
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

