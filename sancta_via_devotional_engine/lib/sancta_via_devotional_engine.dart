/// Pure Dart engine for Catholic devotional programs.
///
/// This library provides the core models for scheduling devotional sessions,
/// representing prayer content, and tracking progress. Its only dependency
/// is the pure Dart liturgical calendar library, and it can be consumed by
/// any Dart or Flutter project in the Sancta Via monorepo.
///
/// ## Basic Usage
///
/// ```dart
/// import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
///
/// final prayer = PrayerText(
///   id: 'memorare',
///   text: 'Remember, O most gracious Virgin Mary...',
///   source: 'Traditional',
///   license: 'public-domain',
/// );
///
/// print(prayer.toJson());
/// ```
library sancta_via_devotional_engine;

// Errors
export 'src/content_validation_exception.dart';

// Models
export 'src/models/content_pack.dart';
export 'src/models/prayer_text.dart';
export 'src/models/schedule_context.dart';
export 'src/models/schedule_result.dart';
export 'src/models/schedule_spec.dart';
export 'src/models/session_script.dart';

// Content
export 'src/content/pack_loader.dart';

// Scheduling
export 'src/scheduling/consecration_planner.dart';
export 'src/scheduling/computus.dart';
export 'src/scheduling/season_overrides.dart';

// Sessions
export 'src/session/session_runner.dart';

// Progress
export 'src/progress/commitment_state.dart';
