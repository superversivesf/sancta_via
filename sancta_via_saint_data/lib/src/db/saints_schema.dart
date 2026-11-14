import 'package:sqflite_common/sqflite.dart';

/// Schema version stamped into `assets/saints.db` as `PRAGMA user_version`.
///
/// The repository bumps this whenever the schema changes; older on-device
/// copies of the database are re-copied from the bundled asset (version 2
/// adds the grounded saint histories: `saints.history`, `saints.history_source`,
/// and the per-saint `sources` table).
const int saintsSchemaVersion = 2;

/// The `assets/saints.db` DDL: the spec section 6 tables plus the schema v2
/// statements (grounded saint histories).
///
/// Executed in order by [createSaintsDatabase] (the v2 statements ride as
/// straight `ALTER`/`CREATE` lines because the build tool always creates the
/// database from scratch). Search text (FTS `name`, `patronages`, `bio`,
/// `prayer`) is written **pre-normalized** by the build tool via
/// `normalizeSearchText`, so the query side shares one normalization pass
/// with the indexed side.
const List<String> saintsSchemaStatements = <String>[
  'CREATE TABLE saints (\n'
      '  slug TEXT PRIMARY KEY,\n'
      '  name TEXT NOT NULL,\n'
      "  feast_day TEXT NOT NULL,          -- 'MM-DD' or 'unknown'\n"
      '  canonized TEXT,\n'
      '  bio TEXT NOT NULL,\n'
      '  prayer_text TEXT,\n'
      "  prayer_source TEXT,               -- 'traditional' | 'original'\n"
      '  featured INTEGER NOT NULL DEFAULT 0,\n'
      "  thumb_asset TEXT,                 -- 'packages/saint_data/assets/thumbs/<slug>.jpg' when shipped\n"
      '  image_attribution TEXT,\n'
      '  image_alt TEXT\n'
      ')',
  'CREATE INDEX idx_saints_feast ON saints(feast_day)',
  'CREATE INDEX idx_saints_featured ON saints(featured)',
  'CREATE TABLE patronages (\n'
      '  slug TEXT NOT NULL REFERENCES saints(slug),\n'
      '  need TEXT NOT NULL,\n'
      '  category TEXT NOT NULL\n'
      ')',
  'CREATE INDEX idx_patronages_category ON patronages(category)',
  'CREATE INDEX idx_patronages_need ON patronages(need)',
  'CREATE TABLE need_synonyms (\n'
      '  need TEXT NOT NULL,\n'
      '  synonym TEXT NOT NULL\n'
      ')',
  'CREATE INDEX idx_synonyms_synonym ON need_synonyms(synonym)',
  "CREATE VIRTUAL TABLE saint_fts USING fts4(\n"
      '  slug, name, patronages, bio, prayer,\n'
      "  tokenize = 'unicode61'\n"
      ')',
  // Schema v2 (saint histories): accepted 400-4000-char grounded history
  // bodies merged at build time from data/histories.json, and the per-saint
  // source URLs (ordered by `position`) backing every record.
  'ALTER TABLE saints ADD COLUMN history TEXT',
  'ALTER TABLE saints ADD COLUMN history_source TEXT',
  'CREATE TABLE sources (\n'
      '  slug TEXT NOT NULL,\n'
      '  url TEXT NOT NULL,\n'
      '  position INTEGER NOT NULL,\n'
      '  PRIMARY KEY (slug, position)\n'
      ')',
];

/// Creates every table, index, and the FTS4 virtual table on [db], then
/// stamps `PRAGMA user_version = saintsSchemaVersion`.
///
/// The FTS virtual table's row content is filled by the build tool
/// (`tools/build_saints_db.dart`) with pre-normalized text; the app never
/// writes to the database after that.
Future<void> createSaintsDatabase(Database db) async {
  for (final String statement in saintsSchemaStatements) {
    await db.execute(statement);
  }
  await db.execute('PRAGMA user_version = $saintsSchemaVersion');
}
