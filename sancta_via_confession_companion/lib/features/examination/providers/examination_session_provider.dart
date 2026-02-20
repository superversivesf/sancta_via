import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/examination_session_model.dart';
import '../models/examination_response_status.dart';
import '../repositories/examination_repository.dart';
import '../../../utils/logger.dart';

// Re-export the repository provider for convenience
export '../repositories/examination_repository.dart'
    show examinationRepositoryProvider;

// Provider for the current examination session
final examinationSessionProvider =
    StateNotifierProvider<ExaminationSessionNotifier, ExaminationSession?>((
      ref,
    ) {
      final repository = ref.watch(examinationRepositoryProvider);
      return ExaminationSessionNotifier(repository);
    });

class ExaminationSessionNotifier extends StateNotifier<ExaminationSession?> {
  final ExaminationRepository repository;

  ExaminationSessionNotifier(this.repository) : super(null) {
    _loadActiveSession();
  }

  // Load any existing active session on startup
  Future<void> _loadActiveSession() async {
    try {
      final activeSession = await repository.getActiveSession();
      if (mounted && activeSession != null) {
        AppLogger.examination('Loaded active session: ${activeSession.id}');
        state = activeSession;
      }
    } catch (e) {
      AppLogger.error('Failed to load active session', e, null, 'EXAM');
    }
  }

  // Start a new examination
  Future<void> startExamination(String examinationId) async {
    try {
      AppLogger.examination(
        'Starting new examination session for: $examinationId',
      );

      final newSession = ExaminationSession(examinationId: examinationId);

      // Save immediately to secure storage
      await repository.saveActiveSession(newSession);

      if (mounted) {
        state = newSession;
        AppLogger.examination(
          'New session created and set as state: ${newSession.id}',
        );
      }
    } catch (e) {
      AppLogger.error('Failed to start examination', e, null, 'EXAM');
      rethrow;
    }
  }

  // Update current position in examination
  Future<void> updatePosition(String categoryId, String itemId) async {
    if (state == null) return;

    try {
      final updatedSession = state!.copyWith(
        currentCategoryId: categoryId,
        currentItemId: itemId,
      );

      // Save to secure storage
      await repository.saveActiveSession(updatedSession);

      if (mounted) {
        state = updatedSession;
        AppLogger.examination(
          'Updated position - Category: $categoryId, Item: $itemId',
        );
      }
    } catch (e) {
      AppLogger.error('Failed to update examination position', e, null, 'EXAM');
    }
  }

  // Set response status for an item
  Future<void> setResponseStatus(
    String itemId,
    ExaminationResponseStatus status,
  ) async {
    if (state == null) return;

    try {
      final updatedResponses = Map<String, ExaminationResponseStatus>.from(
        state!.itemResponses,
      );
      updatedResponses[itemId] = status;

      final updatedSession = state!.copyWith(itemResponses: updatedResponses);

      // Save to secure storage
      await repository.saveActiveSession(updatedSession);

      if (mounted) {
        state = updatedSession;
        AppLogger.examination('Set response status for $itemId: $status');
      }
    } catch (e) {
      AppLogger.error('Failed to set response status', e, null, 'EXAM');
    }
  }

  // Update note for an item
  Future<void> updateNote(String itemId, String note) async {
    if (state == null) return;

    try {
      final updatedNotes = Map<String, String>.from(state!.notes);
      if (note.isNotEmpty) {
        updatedNotes[itemId] = note;
      } else {
        updatedNotes.remove(itemId);
      }

      final updatedSession = state!.copyWith(notes: updatedNotes);

      // Save to secure storage
      await repository.saveActiveSession(updatedSession);

      if (mounted) {
        state = updatedSession;
        AppLogger.examination('Updated note for $itemId');
      }
    } catch (e) {
      AppLogger.error('Failed to update note', e, null, 'EXAM');
    }
  }

  // Complete the examination
  Future<void> completeExamination() async {
    if (state == null) return;

    try {
      AppLogger.examination('Completing examination session: ${state!.id}');

      // Complete and archive the session
      await repository.completeSession(state!);

      if (mounted) {
        state = null; // Clear current session
        AppLogger.examination('Examination completed and session cleared');
      }
    } catch (e) {
      AppLogger.error('Failed to complete examination', e, null, 'EXAM');
      rethrow;
    }
  }

  // Cancel/abandon current examination
  Future<void> cancelExamination() async {
    if (state == null) return;

    try {
      AppLogger.examination('Cancelling examination session: ${state!.id}');

      // Just clear the active session without archiving
      await repository.deleteSession(state!.id);

      if (mounted) {
        state = null;
        AppLogger.examination('Examination cancelled and session cleared');
      }
    } catch (e) {
      AppLogger.error('Failed to cancel examination', e, null, 'EXAM');
    }
  }

  // Resume examination (if there's an active session)
  Future<void> resumeExamination() async {
    await _loadActiveSession();
  }
}
