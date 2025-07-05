import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/examination_model.dart';
import '../models/examination_session_model.dart';
import '../models/user_preferences_model.dart';
import '../models/confession_item_model.dart';
import '../models/examination_response_status.dart';
import '../repositories/examination_repository.dart';
import 'examination_session_provider.dart';
import '../../../utils/logger.dart';

// Provider for the repository
final examinationRepositoryProvider = Provider<ExaminationRepository>((ref) {
  return ExaminationRepository();
});

// Provider for available examinations
final examinationsProvider = FutureProvider<List<ExaminationModel>>((ref) async {
  final repository = ref.watch(examinationRepositoryProvider);
  return await repository.getExaminations();
});

// Provider for a specific examination by ID
final examinationByIdProvider = FutureProvider.family<ExaminationModel?, String>((ref, id) async {
  AppLogger.examination("examinationByIdProvider called with ID: $id");
  final repository = ref.watch(examinationRepositoryProvider);
  final result = await repository.getExaminationById(id);
  if (result == null) {
    AppLogger.examination("Examination with ID $id not found");
  } else {
    AppLogger.examination("Successfully loaded examination: ${result.title}");
  }
  return result;
});

final examinationsUpdateProvider = FutureProvider<bool>((ref) async {
  final repository = ref.watch(examinationRepositoryProvider);
  return await repository.checkForUpdates();
});

// Provider to trigger examination updates
final examinationsUpdateTriggerProvider = FutureProvider.autoDispose<bool>((ref) async {
  final repository = ref.watch(examinationRepositoryProvider);
  final result = await repository.downloadUpdates();

  // Refresh examinations list if update successful
  if (result) {
    ref.invalidate(examinationsProvider);
  }

  return result;
});

// Provider for user preferences
final examinationPreferencesProvider = StateNotifierProvider<ExaminationPreferencesNotifier, ExaminationPreferences>((ref) {
  final repository = ref.watch(examinationRepositoryProvider);
  return ExaminationPreferencesNotifier(repository);
});

// Notifier class for preferences
class ExaminationPreferencesNotifier extends StateNotifier<ExaminationPreferences> {
  final ExaminationRepository repository;

  ExaminationPreferencesNotifier(this.repository) : super(ExaminationPreferences()) {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final preferences = await repository.getUserPreferences();
      if (mounted) {
        state = preferences;
      }
    } catch (e) {
      AppLogger.error('Failed to load examination preferences', e, null, 'EXAM');
    }
  }

  Future<void> toggleFavorite(String examinationId) async {
    try {
      // Optimistic update first
      final currentFavorites = List<String>.from(state.favoriteExaminationIds);
      if (currentFavorites.contains(examinationId)) {
        currentFavorites.remove(examinationId);
      } else {
        currentFavorites.add(examinationId);
      }
      
      if (mounted) {
        state = state.copyWith(favoriteExaminationIds: currentFavorites);
      }

      // Then persist to storage
      final updatedPreferences = await repository.toggleFavorite(examinationId);
      
      // Update state with persisted result if still mounted
      if (mounted) {
        state = updatedPreferences;
      }
    } catch (e) {
      AppLogger.error('Failed to toggle favorite examination', e, null, 'EXAM');
      // Reload preferences to ensure consistency
      await _loadPreferences();
    }
  }

  Future<void> setDefaultExamination(String? examinationId) async {
    try {
      // Optimistic update first
      if (mounted) {
        state = state.copyWith(defaultExaminationId: examinationId);
      }

      // Then persist to storage
      final updatedPreferences = await repository.setDefaultExamination(examinationId);
      
      // Update state with persisted result if still mounted
      if (mounted) {
        state = updatedPreferences;
      }
    } catch (e) {
      AppLogger.error('Failed to set default examination', e, null, 'EXAM');
      // Reload preferences to ensure consistency
      await _loadPreferences();
    }
  }

  Future<void> updatePreferences(ExaminationPreferences preferences) async {
    try {
      await repository.saveUserPreferences(preferences);
      if (mounted) {
        state = preferences;
      }
    } catch (e) {
      AppLogger.error('Failed to update examination preferences', e, null, 'EXAM');
      // Reload preferences to ensure consistency
      await _loadPreferences();
    }
  }
}

// Provider for favorite examinations
final favoriteExaminationsProvider = Provider<List<ExaminationModel>>((ref) {
  final examinations = ref.watch(examinationsProvider).value ?? [];
  final preferences = ref.watch(examinationPreferencesProvider);

  if (preferences.favoriteExaminationIds.isEmpty) {
    return [];
  }

  return examinations
      .where((exam) => preferences.favoriteExaminationIds.contains(exam.id))
      .toList();
});

// Provider for default examination
final defaultExaminationProvider = Provider<ExaminationModel?>((ref) {
  final examinations = ref.watch(examinationsProvider).value ?? [];
  final preferences = ref.watch(examinationPreferencesProvider);

  if (preferences.defaultExaminationId == null) {
    return null;
  }

  try {
    return examinations.firstWhere(
      (exam) => exam.id == preferences.defaultExaminationId,
    );
  } catch (e) {
    return null;
  }
});

final completedExaminationsProvider = FutureProvider<List<ExaminationSession>>((ref) async {
  final repository = ref.watch(examinationRepositoryProvider);
  return await repository.getCompletedSessions();
});

// Provider for generating confession items from current session
final confessionItemsProvider = Provider<List<ConfessionItem>>((ref) {
  final session = ref.watch(examinationSessionProvider);
  final examinationAsync = ref.watch(examinationsProvider);

  if (session == null || !examinationAsync.hasValue) {
    return [];
  }

  final examinations = examinationAsync.value ?? [];
  final examination = examinations.firstWhere(
    (exam) => exam.id == session.examinationId,
    orElse: () => throw StateError('Examination not found'),
  );

  final List<ConfessionItem> items = [];

  for (final category in examination.categories) {
    for (final item in category.items) {
      final status = session.itemResponses[item.id];
      if (status == ExaminationResponseStatus.needConfess) {
        items.add(ConfessionItem.fromExaminationItem(
          itemText: item.text,
          note: session.notes[item.id],
          isMortal: false,
        ));
      }
    }
  }

  return items;
});

// Provider for a specific completed session
final completedSessionProvider = FutureProvider.family<ExaminationSession?, String>((ref, id) async {
  final repository = ref.watch(examinationRepositoryProvider);
  final sessions = await repository.getCompletedSessions();
  
  final matchingSessions = sessions.where((s) => s.id == id).toList();
  return matchingSessions.isNotEmpty ? matchingSessions.first : null;
});

// Provider for generating confession items from a completed session
final completedSessionItemsProvider = Provider.family<List<ConfessionItem>, String>((ref, sessionId) {
  final sessionAsync = ref.watch(completedSessionProvider(sessionId));

  if (!sessionAsync.hasValue || sessionAsync.value == null) {
    return [];
  }

  final session = sessionAsync.value!;
  final examinationAsync = ref.watch(examinationByIdProvider(session.examinationId));

  if (!examinationAsync.hasValue || examinationAsync.value == null) {
    return [];
  }

  final examination = examinationAsync.value!;
  final List<ConfessionItem> items = [];

  for (final category in examination.categories) {
    for (final item in category.items) {
      final status = session.itemResponses[item.id];
      if (status == ExaminationResponseStatus.needConfess) {
        items.add(ConfessionItem.fromExaminationItem(
          itemText: item.text,
          note: session.notes[item.id],
          isMortal: false,
        ));
      }
    }
  }

  return items;
});
