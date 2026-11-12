// Grace-window checkpoint credit tests (Plan 2, Task 8).
//
// Pins the credit semantics the Task 9 ProgressService consumes:
//
// - `creditCheckpoints` is the pinned single-anchor view: checkpoint item →
//   the completed date crediting it for that anchor (exact-day completion by
//   the engine's documented `<item>:<yyyy-mm-dd>` key convention, else the
//   in-window completion), for the spec's GraceWindow items only — missing
//   entries are unsatisfied.
// - `creditCheckpointsForAnchors` is the authoritative multi-anchor
//   evaluation carrying the first-come credit lock: one completion can
//   credit exactly one anchor, even when both anchors' windows admit it
//   (the double-anchor scenario: one confession between two First Saturdays
//   credits exactly the nearer anchor; the second stays uncredited, visible
//   in the returned map).
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_devotionals/services/grace_window_service.dart';

/// The Five First Saturdays schedule shape: First-Saturday anchors, the
/// strict restart policy, and the given confession grace windows.
ConsecutiveCommitmentSpec _saturdaysSpec({List<GraceWindow>? windows}) {
  return ConsecutiveCommitmentSpec(
    anchor: NthWeekdayOfMonthSpec(DateTime.saturday, 1),
    count: 5,
    policy: RestartPolicy.strict,
    windows: windows ?? const <GraceWindow>[],
  );
}

/// The pack's own First-Saturday confession grace: 8 days before and after.
final List<GraceWindow> _packConfessionWindow = <GraceWindow>[
  GraceWindow(item: 'confession', beforeDays: 8, afterDays: 8),
];

/// A wide confession grace (±20 days) under which one confession made
/// between the First Saturdays of November and December 2026 lies inside
/// BOTH anchors' windows — the shape the credit lock exists for.
final List<GraceWindow> _wideConfessionWindow = <GraceWindow>[
  GraceWindow(item: 'confession', beforeDays: 20, afterDays: 20),
];

void main() {
  group('GraceWindowService.creditCheckpoints (single-anchor view)', () {
    test('exact-day completion credits the anchor by the dated key', () {
      final Map<String, DateTime> credits =
          GraceWindowService.creditCheckpoints(
            spec: _saturdaysSpec(windows: _packConfessionWindow),
            anchor: DateTime(2026, 11, 7),
            completedItemsByDay: <String, String>{
              'confession:2026-11-07': 'First Saturday confession',
            },
          );

      expect(credits, <String, DateTime>{'confession': DateTime(2026, 11, 7)});
    });

    test('window-only completion credits with the completion date', () {
      // Confession eight days BEFORE the First Saturday: the ±8 window's
      // inclusive edge. The map's value is the completion date — not the
      // anchor date — so the UI can show what credited the anchor.
      final Map<String, DateTime> credits =
          GraceWindowService.creditCheckpoints(
            spec: _saturdaysSpec(windows: _packConfessionWindow),
            anchor: DateTime(2026, 11, 7),
            completedItemsByDay: <String, String>{
              'confession:2026-10-30': 'eight days early',
            },
          );

      expect(credits, <String, DateTime>{'confession': DateTime(2026, 10, 30)});
    });

    test('window-only completion after the anchor credits the same way', () {
      // Confession eight days AFTER the First Saturday (the other inclusive
      // edge): still credited.
      final Map<String, DateTime> credits =
          GraceWindowService.creditCheckpoints(
            spec: _saturdaysSpec(windows: _packConfessionWindow),
            anchor: DateTime(2026, 11, 7),
            completedItemsByDay: <String, String>{
              'confession:2026-11-15': 'eight days late',
            },
          );

      expect(credits, <String, DateTime>{'confession': DateTime(2026, 11, 15)});
    });

    test('exact-day completion outranks an earlier in-window completion', () {
      // Both completions sit inside the window, but the pinned interface
      // credits the exact-day completion first — the anchor-day confession
      // wins over the one made eight days before, even though the earlier
      // completion would otherwise lock first under date order.
      final Map<String, DateTime> credits =
          GraceWindowService.creditCheckpoints(
            spec: _saturdaysSpec(windows: _packConfessionWindow),
            anchor: DateTime(2026, 11, 7),
            completedItemsByDay: <String, String>{
              'confession:2026-10-30': 'eight days early',
              'confession:2026-11-07': 'on the day',
            },
          );

      expect(credits, <String, DateTime>{'confession': DateTime(2026, 11, 7)});
    });

    test('a completion outside the window is not credited', () {
      // November 16 is nine days after the anchor — past the ±8 grace.
      final Map<String, DateTime> credits =
          GraceWindowService.creditCheckpoints(
            spec: _saturdaysSpec(windows: _packConfessionWindow),
            anchor: DateTime(2026, 11, 7),
            completedItemsByDay: <String, String>{
              'confession:2026-11-16': 'nine days late',
            },
          );

      expect(credits, isEmpty);
    });

    test('only the spec\'s grace-window items are credited', () {
      // Communion and the rosary have no GraceWindow in the spec: they are
      // anchor-day items whose credit is the session layer's concern, not
      // this window service's — they never appear in the map even when
      // completed on the anchor day itself. (ConsecutiveCommitmentSpec
      // carries no required/optional item concept — the only item-keyed
      // shape on the spec is its GraceWindow list.)
      final Map<String, DateTime> credits =
          GraceWindowService.creditCheckpoints(
            spec: _saturdaysSpec(windows: _packConfessionWindow),
            anchor: DateTime(2026, 11, 7),
            completedItemsByDay: <String, String>{
              'confession:2026-11-07': 'First Saturday confession',
              'communion:2026-11-07': 'First Saturday Mass',
              'rosary:2026-11-07': 'five decades',
            },
          );

      expect(credits.keys, <String>['confession']);
    });

    test(
      'keys not following the <item>:<yyyy-mm-dd> convention are ignored',
      () {
        // Progress keys are app-authored; a malformed key must never throw or
        // invent a credit. Unpadded and non-date remainders fail the
        // zero-padded convention and are dropped.
        final Map<String, DateTime> credits =
            GraceWindowService.creditCheckpoints(
              spec: _saturdaysSpec(windows: _packConfessionWindow),
              anchor: DateTime(2026, 11, 7),
              completedItemsByDay: <String, String>{
                'confession:2026-11-7': 'unpadded day',
                'confession:not-a-date': 'garbage',
                'noseparator': 'garbage',
                'confession:2026-11-07': 'First Saturday confession',
              },
            );

        expect(credits, <String, DateTime>{
          'confession': DateTime(2026, 11, 7),
        });
      },
    );

    test(
      'anchor and completion are judged date-only, ignoring time-of-day',
      () {
        final Map<String, DateTime> credits =
            GraceWindowService.creditCheckpoints(
              spec: _saturdaysSpec(windows: _packConfessionWindow),
              anchor: DateTime(2026, 11, 7, 18, 30),
              completedItemsByDay: <String, String>{
                'confession:2026-11-07': 'First Saturday confession',
              },
            );

        expect(credits, <String, DateTime>{
          'confession': DateTime(2026, 11, 7),
        });
      },
    );

    test('an anchor with no spec windows credits nothing', () {
      final Map<String, DateTime> credits =
          GraceWindowService.creditCheckpoints(
            spec: _saturdaysSpec(),
            anchor: DateTime(2026, 11, 7),
            completedItemsByDay: <String, String>{
              'confession:2026-11-07': 'First Saturday confession',
            },
          );

      expect(credits, isEmpty);
    });
  });

  group('GraceWindowService.creditCheckpointsForAnchors (the credit lock)', () {
    test('one confession between two First Saturdays credits the nearer '
        'anchor only', () {
      // November 15, 2026 lies 8 days after the November 7 First Saturday
      // and 20 days before the December 5 First Saturday — inside BOTH
      // anchors' ±20 windows. First-come greedy resolution credits the
      // completion to the NEARER anchor (November 7), and the December
      // anchor stays uncredited — visible as its empty entry in the
      // returned map. Without the lock, a naive per-anchor evaluation would
      // credit the same confession to both First Saturdays.
      final Map<DateTime, Map<String, DateTime>> credited =
          GraceWindowService.creditCheckpointsForAnchors(
            spec: _saturdaysSpec(windows: _wideConfessionWindow),
            anchors: <DateTime>[DateTime(2026, 11, 7), DateTime(2026, 12, 5)],
            completedItemsByDay: <String, String>{
              'confession:2026-11-15': 'one confession, two First Saturdays',
            },
          );

      expect(credited.keys, <DateTime>[
        DateTime(2026, 11, 7),
        DateTime(2026, 12, 5),
      ]);
      expect(credited[DateTime(2026, 11, 7)], <String, DateTime>{
        'confession': DateTime(2026, 11, 15),
      });
      expect(credited[DateTime(2026, 12, 5)], isEmpty);
    });

    test('a second completion fills the farther anchor the first locked '
        'out', () {
      // The November 15 confession is locked to the nearer November 7
      // anchor even though it also admits December 5. The later November 20
      // confession also admits BOTH anchors, but November 7's slot is
      // already filled — it credits December 5. One completion per anchor,
      // no completion credited twice.
      final Map<DateTime, Map<String, DateTime>> credited =
          GraceWindowService.creditCheckpointsForAnchors(
            spec: _saturdaysSpec(windows: _wideConfessionWindow),
            anchors: <DateTime>[DateTime(2026, 12, 5), DateTime(2026, 11, 7)],
            completedItemsByDay: <String, String>{
              'confession:2026-11-15': 'nearer confession',
              'confession:2026-11-20': 'later confession',
            },
          );

      expect(credited[DateTime(2026, 11, 7)], <String, DateTime>{
        'confession': DateTime(2026, 11, 15),
      });
      expect(credited[DateTime(2026, 12, 5)], <String, DateTime>{
        'confession': DateTime(2026, 11, 20),
      });
    });

    test('the earliest completion locks the credit under date order', () {
      // Two in-window completions and no exact-day one: first-come greedy
      // resolution credits the EARLIEST completion (October 30) — it cannot
      // be replaced by the nearer November 5 confession, and the nearer one
      // stays uncredited because the anchor's slot is filled.
      final Map<DateTime, Map<String, DateTime>> credited =
          GraceWindowService.creditCheckpointsForAnchors(
            spec: _saturdaysSpec(windows: _packConfessionWindow),
            anchors: <DateTime>[DateTime(2026, 11, 7)],
            completedItemsByDay: <String, String>{
              'confession:2026-10-30': 'eight days early',
              'confession:2026-11-05': 'two days early',
            },
          );

      expect(credited[DateTime(2026, 11, 7)], <String, DateTime>{
        'confession': DateTime(2026, 10, 30),
      });
    });

    test('a completion crediting one anchor still leaves distinct items '
        'free', () {
      // The lock is per completion record (item + date), not per day: a
      // confession and a meditation completed the same day both credit the
      // same anchor.
      final List<GraceWindow> windows = <GraceWindow>[
        GraceWindow(item: 'confession', beforeDays: 8, afterDays: 8),
        GraceWindow(item: 'meditation', beforeDays: 8, afterDays: 8),
      ];
      final Map<DateTime, Map<String, DateTime>> credited =
          GraceWindowService.creditCheckpointsForAnchors(
            spec: _saturdaysSpec(windows: windows),
            anchors: <DateTime>[DateTime(2026, 11, 7), DateTime(2026, 12, 5)],
            completedItemsByDay: <String, String>{
              'confession:2026-11-15': 'confession',
              'meditation:2026-11-15': 'fifteen minutes',
            },
          );

      expect(credited[DateTime(2026, 11, 7)], <String, DateTime>{
        'confession': DateTime(2026, 11, 15),
        'meditation': DateTime(2026, 11, 15),
      });
      expect(credited[DateTime(2026, 12, 5)], isEmpty);
    });

    test('the single-anchor view matches the locked evaluation for one '
        'anchor', () {
      // creditCheckpoints is stateless per call: evaluated alone, the
      // December 5 anchor would credit the November 15 confession too. The
      // lock lives in creditCheckpointsForAnchors — the multi-anchor call
      // is the authoritative evaluation the Task 9 ProgressService must
      // consume; creditCheckpoints is only the one-anchor view of it.
      final Map<DateTime, Map<String, DateTime>> credited =
          GraceWindowService.creditCheckpointsForAnchors(
            spec: _saturdaysSpec(windows: _wideConfessionWindow),
            anchors: <DateTime>[DateTime(2026, 11, 7)],
            completedItemsByDay: <String, String>{
              'confession:2026-11-15': 'one confession',
            },
          );

      expect(
        GraceWindowService.creditCheckpoints(
          spec: _saturdaysSpec(windows: _wideConfessionWindow),
          anchor: DateTime(2026, 11, 7),
          completedItemsByDay: <String, String>{
            'confession:2026-11-15': 'one confession',
          },
        ),
        credited[DateTime(2026, 11, 7)],
      );
    });
  });
}
