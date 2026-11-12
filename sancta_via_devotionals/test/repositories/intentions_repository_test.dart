// IntentionsRepository tests (Plan 2, Task 16): the CRUD wrapper over the
// Task-4 `intentions` table.
//
// Runs against the FFI factory like every database test in this app and
// pins:
// - adding an intention and a soul persists both (the user's prayer
//   intentions and their departed souls live in one table, discriminated by
//   `kind`) and both come back through `list` and its kind filter,
// - removing an intention deletes the row (true) and removing an unknown id
//   reports false, never throwing,
// - a blank text and an unknown kind are refused with ArgumentError — the
//   repository validates before the store does, so a write can never add an
//   empty row a later re-seed would inherit,
// - the rows survive a close→reopen on a REAL file-backed store (the
//   runtime shape: the wrapper is stateless over the store),
// - `DevotionalsDatabase.intentions` exposes a wrapper over the SAME store
//   the table helpers act on (Task 6's one-store ruling — no split brain),
//   so reads through the getter see writes made through either path.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_devotionals/database/devotionals_database.dart';
import 'package:sancta_via_devotionals/repositories/intentions_repository.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A fresh, isolated in-memory store open factory.
Future<Database> _openInMemory() =>
    openDatabase(inMemoryDatabasePath, singleInstance: false);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('add and list', () {
    test('persists both kinds and lists them (optionally filtered)', () async {
      final DevotionalsDatabase database = DevotionalsDatabase(
        open: _openInMemory,
      );
      final IntentionsRepository repository = IntentionsRepository(
        database: database,
      );

      final IntentionRow intention = await repository.add(
        kind: 'intention',
        text: 'For a sick friend',
        id: 'intent-1',
      );
      final IntentionRow soul = await repository.add(
        kind: 'soul',
        text: 'Grandmother',
        id: 'soul-1',
      );

      expect(intention.kind, 'intention');
      expect(intention.text, 'For a sick friend');
      expect(intention.id, 'intent-1');
      expect(soul.kind, 'soul');
      expect(soul.text, 'Grandmother');

      final List<IntentionRow> all = await repository.list();
      expect(
        all.map((IntentionRow row) => row.id),
        containsAll(<String>['intent-1', 'soul-1']),
      );
      expect(all, hasLength(2));

      final List<IntentionRow> souls = await repository.list(kind: 'soul');
      expect(souls.map((IntentionRow row) => row.id), <String>['soul-1']);

      final List<IntentionRow> intentions = await repository.list(
        kind: 'intention',
      );
      expect(intentions.map((IntentionRow row) => row.id), <String>[
        'intent-1',
      ]);
    });

    test('adds with a generated id when none is supplied', () async {
      final DevotionalsDatabase database = DevotionalsDatabase(
        open: _openInMemory,
      );
      final IntentionsRepository repository = IntentionsRepository(
        database: database,
      );

      final IntentionRow row = await repository.add(
        kind: 'intention',
        text: 'For peace',
      );
      expect(row.id, isNotEmpty);
      expect(await repository.list(), hasLength(1));
    });
  });

  group('remove', () {
    test('deletes its row and reports unknown ids as false', () async {
      final DevotionalsDatabase database = DevotionalsDatabase(
        open: _openInMemory,
      );
      final IntentionsRepository repository = IntentionsRepository(
        database: database,
      );
      await repository.add(kind: 'soul', text: 'Grandfather', id: 'soul-2');

      expect(await repository.remove('soul-2'), isTrue);
      expect(await repository.list(), isEmpty);
      expect(await repository.remove('soul-2'), isFalse);
    });
  });

  group('validation', () {
    test('refuses a blank text and an unknown kind', () async {
      final DevotionalsDatabase database = DevotionalsDatabase(
        open: _openInMemory,
      );
      final IntentionsRepository repository = IntentionsRepository(
        database: database,
      );

      await expectLater(
        repository.add(kind: 'intention', text: '   '),
        throwsArgumentError,
      );
      await expectLater(
        repository.add(kind: 'petition', text: 'For peace'),
        throwsArgumentError,
      );
      // Nothing was written by the refused calls.
      expect(await repository.list(), isEmpty);
    });
  });

  group('persistence', () {
    test('rows survive a close and reopen on a file-backed store', () async {
      final Directory temporary = await Directory.systemTemp.createTemp(
        'intentions_repo_test',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final String path = '${temporary.path}/reopen.db';

      final DevotionalsDatabase first = DevotionalsDatabase(
        open: () => openDatabase(path),
      );
      await first.intentions.add(
        kind: 'soul',
        text: 'Great-grandmother',
        id: 'soul-3',
      );
      await first.close();

      final DevotionalsDatabase second = DevotionalsDatabase(
        open: () => openDatabase(path),
      );
      final List<IntentionRow> rows = await second.intentions.list();
      expect(rows, hasLength(1));
      expect(rows.single.id, 'soul-3');
      expect(rows.single.kind, 'soul');
      expect(rows.single.text, 'Great-grandmother');
      await second.close();
    });

    test('the database getter exposes a wrapper over the same store', () async {
      final DevotionalsDatabase database = DevotionalsDatabase(
        open: _openInMemory,
      );

      // Written through the getter's wrapper …
      await database.intentions.add(
        kind: 'intention',
        text: 'For the parish',
        id: 'intent-4',
      );
      // … and visible through the raw table helpers of the SAME store.
      final IntentionRow? raw = await database.getIntention('intent-4');
      expect(raw, isNotNull);
      expect(raw!.text, 'For the parish');

      // The reverse too: a raw-table write is visible through the getter.
      await database.insertIntention(
        id: 'soul-4',
        kind: 'soul',
        text: 'A departed friend',
        createdAt: '2026-11-13T08:00:00.000Z',
      );
      final List<IntentionRow> souls = await database.intentions.list(
        kind: 'soul',
      );
      expect(souls.map((IntentionRow row) => row.id), <String>['soul-4']);
    });
  });
}
