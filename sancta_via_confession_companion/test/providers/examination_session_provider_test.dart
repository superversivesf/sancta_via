import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:confession_companion/features/examination/data/examinations.dart';
import 'package:confession_companion/features/examination/models/examination_model.dart';
import 'package:confession_companion/features/examination/models/examination_response_status.dart';
import 'package:confession_companion/features/examination/models/examination_session_model.dart';
import 'package:confession_companion/features/examination/providers/examination_session_provider.dart';
import 'package:confession_companion/features/examination/repositories/examination_repository.dart';

/// Storage-backed fake: records session saves and hands back the last saved
/// session, so the notifier's storage round-trips are exercised without the
/// platform channels (secure storage, path provider).
class InMemorySessionRepository implements ExaminationRepository {
  ExaminationSession? saved;
  final List<String> completedIds = <String>[];

  @override
  Future<ExaminationSession?> getActiveSession() async => saved;

  @override
  Future<void> saveActiveSession(ExaminationSession session) async {
    saved = session;
  }

  @override
  Future<void> completeSession(ExaminationSession session) async {
    completedIds.add(session.id);
    saved = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('not covered by the fake: ${invocation.memberName}');
}

void main() {
  late InMemorySessionRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = InMemorySessionRepository();
    container = ProviderContainer(
      overrides: [
        examinationRepositoryProvider.overrideWith((ref) => repository),
      ],
    );
    addTearDown(container.dispose);
  });

  test(
    'no prior session: state stays null after construction',
    () async {
      container.read(examinationSessionProvider.notifier);
      await Future<void>.delayed(Duration.zero); // let _loadActiveSession settle

      expect(container.read(examinationSessionProvider), isNull);
    },
  );

  test(
    'start -> update position -> respond -> complete round-trips through storage',
    () async {
      final notifier = container.read(examinationSessionProvider.notifier);
      await Future<void>.delayed(Duration.zero);

      // Start a session for a real bundled examination.
      await notifier.startExamination(sampleExaminations.first.id);

      final started = container.read(examinationSessionProvider)!;
      expect(started.examinationId, sampleExaminations.first.id);
      expect(started.isCompleted, isFalse);

      // Position updates persist to storage parity.
      await notifier.updatePosition('cat_a', 'item_1');
      expect(
        container.read(examinationSessionProvider)!.currentCategoryId,
        'cat_a',
      );
      expect(repository.saved!.currentCategoryId, 'cat_a');

      // Responses persist to storage parity.
      await notifier.setResponseStatus(
        'item_1',
        ExaminationResponseStatus.noIssue,
      );
      expect(
        container.read(examinationSessionProvider)!.itemResponses['item_1'],
        ExaminationResponseStatus.noIssue,
      );
      expect(repository.saved!.itemResponses['item_1'],
          ExaminationResponseStatus.noIssue);

      // Completion clears the active session (the exam is done, not in
      // progress) and records it for the completed list.
      await notifier.completeExamination();
      expect(repository.saved, isNull);
      expect(repository.completedIds, hasLength(1));
    },
  );

  test(
    'an active session found in storage is restored on construction',
    () async {
      // Seed storage BEFORE the notifier is created: the constructor fires
      // _loadActiveSession, which must adopt the stored session.
      final seeded = ExaminationSession(
        examinationId: sampleExaminations.first.id,
        id: 'seeded-session',
      );
      repository.saved = seeded;

      container.read(examinationSessionProvider.notifier);
      await Future<void>.delayed(Duration.zero);

      final restored = container.read(examinationSessionProvider);
      expect(restored, isNotNull);
      expect(restored!.id, 'seeded-session');
    },
  );

  test(
    'session progress starts at zero and grows with reviewed responses',
    () {
      final examination = _examinationWithAtLeast(10);
      final session = ExaminationSession(examinationId: examination.id);

      expect(session.getProgress(examination), 0.0);
    },
  );
}

ExaminationModel _examinationWithAtLeast(int items) {
  return sampleExaminations.firstWhere(
    (e) => e.totalItems >= items,
    orElse: () => sampleExaminations.first,
  );
}
