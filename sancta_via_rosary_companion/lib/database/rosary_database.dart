import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class RosaryDatabase {
  static const _databaseName = 'rosary_companion.db';
  static const _databaseVersion = 1;

  RosaryDatabase._privateConstructor();
  static final RosaryDatabase instance = RosaryDatabase._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE mysteries (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        mystery_number INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        scripture_text TEXT NOT NULL,
        meditation_text TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE beads (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        decade_position INTEGER NOT NULL,
        prayer_text TEXT NOT NULL,
        audio_url TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        mystery_type TEXT NOT NULL,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        completed_beads INTEGER NOT NULL,
        is_complete INTEGER NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE statistics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date INTEGER NOT NULL,
        prayers_completed INTEGER NOT NULL,
        time_spent INTEGER NOT NULL
      )
    ''');

    await _seedData(db);
  }

  Future<void> _seedData(Database db) async {
    const mysteries = [
      {
        'id': 'joyful-1',
        'type': 'joyful',
        'mystery_number': 1,
        'title': 'The Annunciation',
        'description':
            'The Angel Gabriel announces to Mary that she will bear the Son of God',
        'scripture_text':
            'Hail, full of grace, the Lord is with you! (Luke 1:28)',
        'meditation_text':
            'We pray for humility and acceptance of God\'s will in our lives.',
      },
      {
        'id': 'joyful-2',
        'type': 'joyful',
        'mystery_number': 2,
        'title': 'The Visitation',
        'description': 'Mary visits her cousin Elizabeth',
        'scripture_text':
            'Blessed are you among women, and blessed is the fruit of your womb! (Luke 1:42)',
        'meditation_text':
            'We pray for charity and service to others, especially those in need.',
      },
      {
        'id': 'joyful-3',
        'type': 'joyful',
        'mystery_number': 3,
        'title': 'The Nativity',
        'description': 'Jesus is born in Bethlehem',
        'scripture_text':
            'She gave birth to her firstborn son and wrapped him in swaddling clothes. (Luke 2:7)',
        'meditation_text':
            'We pray for detachment from worldly goods and simplicity of life.',
      },
      {
        'id': 'joyful-4',
        'type': 'joyful',
        'mystery_number': 4,
        'title': 'The Presentation',
        'description': 'Mary and Joseph present Jesus in the Temple',
        'scripture_text':
            'Now, Master, you may let your servant go in peace, according to your word. (Luke 2:29)',
        'meditation_text':
            'We pray for obedience to God\'s will and purification of our intentions.',
      },
      {
        'id': 'joyful-5',
        'type': 'joyful',
        'mystery_number': 5,
        'title': 'The Finding in the Temple',
        'description': 'Jesus is found teaching in the Temple at age twelve',
        'scripture_text':
            'Did you not know that I must be in my Father\'s house? (Luke 2:49)',
        'meditation_text':
            'We pray for true wisdom and devotion to our duties and responsibilities.',
      },
    ];

    const beads = [
      {
        'id': 'apostles_creed',
        'type': 'apostles_creed',
        'decade_position': 0,
        'prayer_text':
            'I believe in God, the Father almighty, creator of heaven and earth...',
      },
      {
        'id': 'our_father_1',
        'type': 'our_father',
        'decade_position': 0,
        'prayer_text': 'Our Father, who art in heaven, hallowed be thy Name...',
      },
    ];

    for (final mystery in mysteries) {
      await db.insert('mysteries', mystery);
    }

    for (final bead in beads) {
      await db.insert('beads', bead);
    }
  }
}
