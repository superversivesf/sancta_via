# Sancta Via Devotional Engine Riverpod

Reactive Riverpod providers for **sancta_via_devotional_engine** — the
scheduling, session, and progress engine for Catholic devotional programs.

Part of the **Sancta Via Catholic Apps Ecosystem**.

## 📦 What This Package Provides

- **`ProgramRepository`** — the persistence seam between the engine and
  the app: loading content packs, reading and saving progress, and
  enrolling in programs.
- **`InMemoryProgramRepository`** — a demo-ready implementation preloaded
  with the engine's fixture packs, compiled in as generated Dart sources
  (no assets, no I/O).
- **Providers** — thin reactive wiring over the repository and the
  liturgical calendar's date providers:

| Provider | Provides |
|---|---|
| `programRepositoryProvider` | The repository the providers read through (override in tests and the app) |
| `enrolledProgramsProvider` | Every repository program, paired with its saved progress |
| `todayProgramsProvider` | The programs whose session is due on the current date |
| `programDetailProvider(packId)` | One program's pack, progress, restart policy, and remaining anchor projection |

The wrapper is deliberately thin: all scheduling (`ScheduleSpec.resolve`),
season overrides (`ScheduleContext`), progress, missed-day, and
projection semantics stay in the engine; these providers only combine
repository data, the current date, and engine calls.

## 🚀 Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_devotional_engine_riverpod/sancta_via_devotional_engine_riverpod.dart';

class TodayWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProgramsProvider);

    return today.when(
      data: (due) => ListView(
        children: [
          for (final program in due)
            ListTile(
              title: Text(program.pack.title),
              subtitle: Text(program.schedule.toString()),
            ),
        ],
      ),
      loading: () => const CircularProgressIndicator(),
      error: (error, stackTrace) => Text('$error'),
    );
  }
}
```

## 🔩 Embedded Packs

`InMemoryProgramRepository` ships with the engine's fixture packs
embedded in `lib/src/embedded_packs.dart` — a generated `const` map of
pack id to raw pack JSON, parsed through the engine's `PackLoader` (and
therefore fully validated) when the repository is first used.

**Regeneration:** whenever a fixture pack changes in the engine, or a
new pack fixture lands, regenerate the embedded map from the package
root:

```sh
dart tool/embed_packs.dart
```

The tool (`tool/embed_packs.dart`) reads
`../sancta_via_devotional_engine/test/fixtures/packs/*.json` in sorted
filename order, validates the directory through
`PackLoader.loadFixturesIn` (a pack failing validation fails the embed),
and rewrites `lib/src/embedded_packs.dart`. Commit the regenerated file
together with the fixture change.

## 🧪 Testing With Dates

The liturgical calendar's real `currentDateProvider` ticks on a periodic
stream that never completes inside a test, so tests override it with the
mechanism the date providers support — a `Stream.value` override:

```dart
final container = ProviderContainer(
  overrides: [
    // The liturgical calendar's date provider (imported from
    // sancta_via_liturgical_calendar_riverpod).
    currentDateProvider.overrideWith(
      (ref) => Stream<DateTime>.value(DateTime(2026, 12, 5)),
    ),
    programRepositoryProvider.overrideWithValue(myRepository),
  ],
);
```

See `test/program_providers_test.dart` for the full pattern, including
pinning which programs come due on a given liturgical date.
