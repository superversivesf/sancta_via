import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'database_schemas.dart';
import '../models/rosary_mystery.dart';
import '../models/rosary_bead.dart';
import '../models/bead_type.dart';
import '../models/mystery_type.dart';
import '../utils/logger.dart';

class RosaryDatabase {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'rosary_database.db');

    AppLogger.debug('Initializing rosary database at: $path');

    return await openDatabase(
      path,
      version: DatabaseSchemas.roaryDatabaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    AppLogger.debug('Creating rosary database tables...');

    for (final table in DatabaseSchemas.allTables) {
      await db.execute(table);
    }

    await db.execute(DatabaseSchemas.insertDefaultSettings);
    AppLogger.debug('Rosary database tables created successfully');
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    AppLogger.debug('Upgrading rosary database from version $oldVersion to $newVersion');

    if (oldVersion < newVersion) {
      await _onCreate(db, newVersion);
    }
  }

  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      AppLogger.debug('Rosary database closed');
    }
  }

  static Future<void> delete() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'rosary_database.db');
    await deleteDatabase(path);
    _database = null;
    AppLogger.debug('Rosary database deleted');
  }

  static Future<void> seedInitialData() async {
    AppLogger.debug('Seeding initial rosary data...');

    await _seedMysteries();
    await _seedBeads();

    AppLogger.debug('Initial rosary data seeded successfully');
  }

  static Future<void> _seedMysteries() async {
    final db = await database;
    final count = await db.rawQuery('SELECT COUNT(*) FROM mysteries');
    final mysteryCount = (count.first.values.first as int?) ?? 0;

    if (mysteryCount > 0) {
      AppLogger.debug('Mysteries already seeded, skipping...');
      return;
    }

    const mysteries = [
      {
        'id': 'joyful-1',
        'type': 'joyful',
        'mystery_number': 1,
        'title': 'The Annunciation',
        'description': 'The Angel Gabriel announces to Mary that she will bear the Son of God',
        'scripture_text': "'Hail, full of grace, the Lord is with you!' (Luke 1:28)",
        'meditation_text': "We pray for humility and acceptance of God's will in our lives.",
      },
      {
        'id': 'joyful-2',
        'type': 'joyful',
        'mystery_number': 2,
        'title': 'The Visitation',
        'description': 'Mary visits her cousin Elizabeth',
        'scripture_text': "'Blessed are you among women, and blessed is the fruit of your womb!' (Luke 1:42)",
        'meditation_text': 'We pray for charity and service to others, especially those in need.',
      },
      {
        'id': 'joyful-3',
        'type': 'joyful',
        'mystery_number': 3,
        'title': 'The Nativity',
        'description': 'Jesus is born in Bethlehem',
        'scripture_text': "'She gave birth to her firstborn son and wrapped him in swaddling clothes.' (Luke 2:7)",
        'meditation_text': 'We pray for detachment from worldly goods and simplicity of life.',
      },
      {
        'id': 'joyful-4',
        'type': 'joyful',
        'mystery_number': 4,
        'title': 'The Presentation',
        'description': 'Mary and Joseph present Jesus in the Temple',
        'scripture_text': "'Now, Master, you may let your servant go in peace, according to your word.' (Luke 2:29)",
        'meditation_text': 'We pray for obedience to God\'s will and purification of our intentions.',
      },
      {
        'id': 'joyful-5',
        'type': 'joyful',
        'mystery_number': 5,
        'title': 'The Finding in the Temple',
        'description': 'Jesus is found teaching in the Temple at age twelve',
        'scripture_text': "'Did you not know that I must be in my Father\'s house?' (Luke 2:49)",
        'meditation_text': 'We pray for true wisdom and devotion to our duties and responsibilities.',
      },
      {
        'id': 'sorrowful-1',
        'type': 'sorrowful',
        'mystery_number': 1,
        'title': 'The Agony in the Garden',
        'description': 'Jesus prays in anguish in the Garden of Gethsemane',
        'scripture_text': "'Father, if you are willing, take this cup away from me; still, not my will but yours be done.' (Luke 22:42)",
        'meditation_text': 'We pray for true contrition for our sins and perseverance in difficult times.',
      },
      {
        'id': 'sorrowful-2',
        'type': 'sorrowful',
        'mystery_number': 2,
        'title': 'The Scourging at the Pillar',
        'description': 'Jesus is brutally scourged by the Roman soldiers',
        'scripture_text': "'I find no guilt in this man.' (Luke 23:4)",
        'meditation_text': 'We pray for purity of soul and mortification of our senses.',
      },
      {
        'id': 'sorrowful-3',
        'type': 'sorrowful',
        'mystery_number': 3,
        'title': 'The Crowning with Thorns',
        'description': 'Jesus is mocked and crowned with thorns',
        'scripture_text': "'Hail, King of the Jews!' (Matthew 27:29)",
        'meditation_text': 'We pray for moral courage and mock the empty pleasures of the world.',
      },
      {
        'id': 'sorrowful-4',
        'type': 'sorrowful',
        'mystery_number': 4,
        'title': 'The Carrying of the Cross',
        'description': 'Jesus carries His cross to Calvary',
        'scripture_text': "'If anyone wishes to come after me, let him deny himself and take up his cross daily.' (Luke 9:23)",
        'meditation_text': 'We pray for patience in bearing our crosses and making sacrifices for others.',
      },
      {
        'id': 'sorrowful-5',
        'type': 'sorrowful',
        'mystery_number': 5,
        'title': 'The Crucifixion',
        'description': 'Jesus dies on the cross for our sins',
        'scripture_text': "'Father, into your hands I commend my spirit.' (Luke 23:46)",
        'meditation_text': 'We pray for final perseverance and a holy death that leads to eternal life.',
      },
      {
        'id': 'glorious-1',
        'type': 'glorious',
        'mystery_number': 1,
        'title': 'The Resurrection',
        'description': 'Jesus rises from the dead on Easter Sunday',
        'scripture_text': "'Why do you seek the living one among the dead? He is not here, but he has been raised.' (Luke 24:5-6)",
        'meditation_text': 'We pray for faith in the resurrection and trust in God\'s promises.',
      },
      {
        'id': 'glorious-2',
        'type': 'glorious',
        'mystery_number': 2,
        'title': 'The Ascension',
        'description': 'Jesus ascends into Heaven forty days after His resurrection',
        'scripture_text': "'Go into the whole world and proclaim the gospel to every creature.' (Mark 16:15)",
        'meditation_text': 'We pray for hope in heavenly glory and detachment from earthly things.',
      },
      {
        'id': 'glorious-3',
        'type': 'glorious',
        'mystery_number': 3,
        'title': 'The Descent of the Holy Spirit',
        'description': 'The Holy Spirit descends upon the Apostles at Pentecost',
        'scripture_text': "'They were all filled with the Holy Spirit and began to speak in different tongues.' (Acts 2:4)",
        'meditation_text': 'We pray for the gifts of the Holy Spirit and zeal for the mission of the Church.',
      },
      {
        'id': 'glorious-4',
        'type': 'glorious',
        'mystery_number': 4,
        'title': 'The Assumption of Mary',
        'description': 'Mary is taken up body and soul into Heaven',
        'scripture_text': "'A great sign appeared in the sky, a woman clothed with the sun.' (Revelation 12:1)",
        'meditation_text': 'We pray for devotion to Mary and a holy death that leads to eternal life.',
      },
      {
        'id': 'glorious-5',
        'type': 'glorious',
        'mystery_number': 5,
        'title': 'The Crowning of Mary as Queen of Heaven and Earth',
        'description': 'Mary is crowned Queen of Heaven and Earth',
        'scripture_text': "'A great sign appeared in the sky, a woman clothed with the sun.' (Revelation 12:1)",
        'meditation_text': 'We pray for trust in Mary\'s intercession and confidence in her maternal protection.',
      },
      {
        'id': 'luminous-1',
        'type': 'luminous',
        'mystery_number': 1,
        'title': 'The Baptism of Jesus',
        'description': 'Jesus is baptized by John the Baptist in the Jordan River',
        'scripture_text': "'This is my beloved Son, with whom I am well pleased.' (Matthew 3:17)",
        'meditation_text': 'We pray for openness to the Holy Spirit and acceptance of our vocation.',
      },
      {
        'id': 'luminous-2',
        'type': 'luminous',
        'mystery_number': 2,
        'title': 'The Wedding at Cana',
        'description': 'Jesus performs His first miracle at the wedding in Cana',
        'scripture_text': "'Do whatever he tells you.' (John 2:5)",
        'meditation_text': 'We pray for trust in Mary\'s intercession and obedience to the Word of God.',
      },
      {
        'id': 'luminous-3',
        'type': 'luminous',
        'mystery_number': 3,
        'title': 'The Proclamation of the Kingdom',
        'description': 'Jesus proclaims the Kingdom of God and calls all to conversion',
        'scripture_text': "'The kingdom of God is at hand. Repent, and believe in the gospel.' (Mark 1:15)",
    };

    for (final mystery in mysteries) {
      await db.insert('mysteries', mystery);
    }
  }

  static Future<void> _seedBeads() async {
    final db = await database;
    final count = await db.rawQuery('SELECT COUNT(*) FROM beads');
    final beadCount = (count.first.values.first as int?) ?? 0;

    if (beadCount > 0) {
      AppLogger.debug('Beads already seeded, skipping...');
      return;
    }

    final List<Map<String, dynamic>> beads = [
      // Opening prayers (7 beads)
      {
        'id': 'bead-001',
        'type': 'sign_of_cross',
        'decade_position': 0,
        'prayer_text': 'In the name of the Father, and of the Son, and of the Holy Spirit. Amen.',
        'audio_url': null,
      },
      {
        'id': 'bead-002',
        'type': 'apostles_creed',
        'decade_position': 0,
        'prayer_text': 'I believe in God, the Father almighty, Creator of heaven and earth, and in Jesus Christ, his only Son, our Lord, who was conceived by the Holy Spirit, born of the Virgin Mary, suffered under Pontius Pilate, was crucified, died and was buried; he descended into hell; on the third day he rose again from the dead; he ascended into heaven, and is seated at the right hand of God the Father almighty; from there he will come to judge the living and the dead. I believe in the Holy Spirit, the holy catholic Church, the communion of saints, the forgiveness of sins, the resurrection of the body, and life everlasting. Amen.',
        'audio_url': null,
      },
      {
        'id': 'bead-003',
        'type': 'our_father',
        'decade_position': 0,
        'prayer_text': 'Our Father, who art in heaven, hallowed be thy name; thy kingdom come; thy will be done on earth as it is in heaven. Give us this day our daily bread; and forgive us our trespasses as we forgive those who trespass against us; and lead us not into temptation, but deliver us from evil. Amen.',
        'audio_url': null,
      },
      {
        'id': 'bead-004',
        'type': 'hail_mary',
        'decade_position': 1,
        'prayer_text': 'Hail Mary, full of grace, the Lord is with thee; blessed art thou among women, and blessed is the fruit of thy womb, Jesus. Holy Mary, Mother of God, pray for us sinners, now and at the hour of our death. Amen.',
        'audio_url': null,
      },
      {
        'id': 'bead-005',
        'type': 'hail_mary',
        'decade_position': 2,
        'prayer_text': 'Hail Mary, full of grace, the Lord is with thee; blessed art thou among women, and blessed is the fruit of thy womb, Jesus. Holy Mary, Mother of God, pray for us sinners, now and at the hour of our death. Amen.',
        'audio_url': null,
      },
      {
        'id': 'bead-006',
        'type': 'hail_mary',
        'decade_position': 3,
        'prayer_text': 'Hail Mary, full of grace, the Lord is with thee; blessed art thou among women, and blessed is the fruit of thy womb, Jesus. Holy Mary, Mother of God, pray for us sinners, now and at the hour of our death. Amen.',
        'audio_url': null,
      },
      {
        'id': 'bead-007',
        'type': 'glory_be',
        'decade_position': 0,
        'prayer_text': 'Glory be to the Father, and to the Son, and to the Holy Spirit. As it was in the beginning, is now, and ever shall be, world without end. Amen.',
        'audio_url': null,
      },
      
      // Decade 1
      {
        {
          'id': 'bead-008',
        'type': 'our_father',
        'decade_position': 0,
        'prayer_text': 'Our Father, who art in heaven, hallowed be thy name; thy kingdom come; thy will be done on earth as it is in heaven. Give us this day our daily bread; and forgive us our trespasses as we forgive those who trespass against us; and lead us not into temptation, but deliver us from evil. Amen.',
        'audio_url': null,
      },
    ];

    for (final bead in beads) {
      await db.insert('beads', bead);
    }
  }
}
