class DatabaseSchemas {
  static const int roaryDatabaseVersion = 1;

  static const mysteriesTable = '''
    CREATE TABLE mysteries (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      mystery_number INTEGER NOT NULL,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      scripture_text TEXT NOT NULL,
      meditation_text TEXT NOT NULL
    )
  ''';

  static const beadsTable = '''
    CREATE TABLE beads (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      decade_position INTEGER NOT NULL,
      mystery_type TEXT, -- joyful, sorrowful, glorious, luminous
      decade_number INTEGER, -- 0-5 (0 = opening prayers, 1-5 = decades)
      prayer_text TEXT NOT NULL,
      audio_url TEXT
    )
  ''';

  static const sessionsTable = '''
    CREATE TABLE sessions (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      start_time INTEGER NOT NULL,
      end_time INTEGER,
      completed_beads INTEGER NOT NULL,
      is_complete INTEGER NOT NULL,
      notes TEXT
    )
  ''';

  static const statisticsTable = '''
    CREATE TABLE statistics (
      id TEXT PRIMARY KEY,
      date INTEGER NOT NULL,
      completed_rosaries INTEGER NOT NULL,
      completed_decades INTEGER NOT NULL,
      type TEXT NOT NULL,
      total_prayer_time_minutes INTEGER NOT NULL
    )
  ''';

  static const settingsTable = '''
    CREATE TABLE settings (
      use_daily_schedule INTEGER NOT NULL,
      preferred_mystery TEXT,
      show_full_text INTEGER NOT NULL,
      enable_bead_counter INTEGER NOT NULL,
      auto_advance INTEGER NOT NULL,
      font_size REAL NOT NULL,
      show_imagery INTEGER NOT NULL
    )
  ''';

  static const insertDefaultSettings = '''
    INSERT INTO settings (
      use_daily_schedule,
      preferred_mystery,
      show_full_text,
      enable_bead_counter,
      auto_advance,
      font_size,
      show_imagery
    ) VALUES (1, NULL, 1, 1, 0, 16.0, 1)
  ''';

  static const allTables = [
    mysteriesTable,
    beadsTable,
    sessionsTable,
    statisticsTable,
    settingsTable,
  ];
}
