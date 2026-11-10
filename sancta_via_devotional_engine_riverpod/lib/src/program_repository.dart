/// The persistence seam between the devotional engine and the app: a
/// [ProgramRepository] supplies content packs and stores the user's
/// enrollment and progress, and [InMemoryProgramRepository] is its
/// demo-ready implementation preloaded with the engine's fixture packs.
///
/// The repository is deliberately thin: it stores and hands back engine
/// values ([ContentPack], [ProgressState]) without interpreting them.
/// Every piece of scheduling, session, and progress semantics stays in
/// `sancta_via_devotional_engine`; the repository never re-implements
/// any of it.
library;

import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';

import 'embedded_packs.dart';

/// The source of devotional programs and their persisted state.
///
/// Implementations own however much durability the app needs (the
/// in-memory implementation here, sqlite in the future app). The
/// methods are asynchronous so a real backing store can do I/O.
abstract class ProgramRepository {
  /// Every program the repository carries, in its own stable order.
  Future<List<ContentPack>> loadPacks();

  /// The user's persisted progress for the pack identified by [packId],
  /// or null when no progress has been saved for it.
  Future<ProgressState?> progressFor(String packId);

  /// Enrolls the user in the program identified by [packId].
  ///
  /// [params] carries enrollment inputs the app layer owns — opaque
  /// here, like a pack's `reminders` map: the repository stores the
  /// value verbatim and never type-assumes inside it (e.g. a planned
  /// start date for the Total Consecration, keyed however Plan 2's
  /// enrollment flow chooses).
  Future<void> enroll(String packId, Map<String, dynamic> params);

  /// Persists [s] as the user's progress for its `ProgressState.packId`.
  Future<void> saveProgress(ProgressState s);
}

/// The embedded fixture packs, parsed once per process.
///
/// The JSON documents are generated into `lib/src/embedded_packs.dart`
/// by `tool/embed_packs.dart`; parsing them through [PackLoader] runs
/// the engine's full validation pass at first use.
final List<ContentPack> _embeddedPacks = <ContentPack>[
  for (final MapEntry<String, String> entry in embeddedPackJson.entries)
    PackLoader.loadFromJsonString(entry.value),
];

/// A [ProgramRepository] holding everything in memory.
///
/// Ships preloaded with the engine's eight fixture packs — the Angelus,
/// the Divine Mercy Novena, the Five First Saturdays, the Hour of
/// Mercy, the Nine First Fridays, the 54-Day Rosary Novena, the Rosary,
/// and the Total Consecration — embedded at build time from the engine
/// fixtures, so the repository needs no asset loading or I/O.
///
/// Tests and demos can instead inject their own packs:
///
/// ```dart
/// final repository = InMemoryProgramRepository(packs: myPacks);
/// ```
class InMemoryProgramRepository implements ProgramRepository {
  /// Creates a repository carrying [packs] (indexed by pack id, in the
  /// given order), or the embedded fixture packs when [packs] is null.
  ///
  /// Throws an [ArgumentError] when [packs] carries two packs with the
  /// same id.
  InMemoryProgramRepository({Iterable<ContentPack>? packs})
    : _packs = _indexPacks(packs ?? _embeddedPacks);

  /// The programs the repository carries, by pack id.
  final Map<String, ContentPack> _packs;

  /// The saved progress states, by pack id.
  final Map<String, ProgressState> _progress = <String, ProgressState>{};

  /// The enrollment params, by pack id.
  final Map<String, Map<String, dynamic>> _enrollmentParams =
      <String, Map<String, dynamic>>{};

  /// The enrollment params of each enrolled program, keyed by pack id —
  /// the values exactly as passed to [enroll], never interpreted.
  Map<String, Map<String, dynamic>> get enrollmentParams =>
      Map<String, Map<String, dynamic>>.unmodifiable(_enrollmentParams);

  @override
  Future<List<ContentPack>> loadPacks() async {
    return List<ContentPack>.unmodifiable(_packs.values);
  }

  @override
  Future<ProgressState?> progressFor(String packId) async {
    return _progress[packId];
  }

  @override
  Future<void> enroll(String packId, Map<String, dynamic> params) async {
    _requireKnownPack(packId, 'enroll in');
    _enrollmentParams[packId] = Map<String, dynamic>.unmodifiable(params);
  }

  @override
  Future<void> saveProgress(ProgressState s) async {
    _requireKnownPack(s.packId, 'save progress for');
    _progress[s.packId] = s;
  }

  /// Throws for a [packId] the repository does not carry, naming the
  /// rejected write [action].
  void _requireKnownPack(String packId, String action) {
    if (!_packs.containsKey(packId)) {
      throw ArgumentError(
        'cannot $action "$packId": no program with that pack id',
      );
    }
  }
}

/// Indexes [packs] by pack id, preserving the given order.
Map<String, ContentPack> _indexPacks(Iterable<ContentPack> packs) {
  final Map<String, ContentPack> index = <String, ContentPack>{};
  for (final ContentPack pack in packs) {
    if (index.containsKey(pack.id)) {
      throw ArgumentError('duplicate program id "${pack.id}"');
    }
    index[pack.id] = pack;
  }
  return index;
}
