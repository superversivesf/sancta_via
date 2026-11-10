/// Riverpod providers for the Sancta Via devotional engine.
///
/// This library wraps `sancta_via_devotional_engine` in a thin reactive
/// seam for Flutter apps: a [ProgramRepository] persistence abstraction
/// with an in-memory implementation preloaded with the engine's fixture
/// packs, and providers exposing the enrolled programs, today's due
/// programs, and per-program detail — all driven by the sibling
/// `sancta_via_liturgical_calendar_riverpod` date providers.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:flutter_riverpod/flutter_riverpod.dart';
/// import 'package:sancta_via_devotional_engine_riverpod/sancta_via_devotional_engine_riverpod.dart';
///
/// class TodayWidget extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final today = ref.watch(todayProgramsProvider);
///
///     return today.when(
///       data: (due) => ListView(
///         children: [
///           for (final program in due)
///             ListTile(title: Text(program.pack.title)),
///         ],
///       ),
///       loading: () => const CircularProgressIndicator(),
///       error: (error, stackTrace) => Text('$error'),
///     );
///   }
/// }
/// ```
///
/// ## Core Providers
///
/// - `programRepositoryProvider` — the repository seam (override with a
///   concrete repository in tests and the app)
/// - `enrolledProgramsProvider` — every repository program with progress
/// - `todayProgramsProvider` — the programs due on the current date
/// - `programDetailProvider(packId)` — one program's detail, including
///   its restart policy string and remaining anchor projection
library;

// The persistence seam and its in-memory implementation.
export 'src/program_repository.dart';

// The program, today, and detail providers.
export 'src/providers/program_providers.dart';

// Re-export the engine for consumer convenience.
export 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
