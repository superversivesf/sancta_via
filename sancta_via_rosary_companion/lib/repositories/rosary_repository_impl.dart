import '../database/rosary_database.dart';
import '../models/rosary_mystery.dart';
import '../models/rosary_bead.dart';
import '../models/bead_type.dart';
import '../models/mystery_type.dart';
import '../utils/logger.dart';
import 'rosary_repository.dart';

class RosaryRepositoryImpl implements RosaryRepository {
  @override
  Future<List<RosaryMystery>> getAllMysteries() async {
    try {
      final db = await RosaryDatabase.instance.database;
      final maps = await db.query('mysteries', orderBy: 'type, mystery_number');

      return maps.map((map) => _mapToMystery(map)).toList();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get all mysteries', e, stackTrace);
      return [];
    }
  }

  @override
  Future<List<RosaryMystery>> getMysteriesByType(String type) async {
    try {
      final db = await RosaryDatabase.instance.database;
      final maps = await db.query(
        'mysteries',
        where: 'type = ?',
        whereArgs: [type],
        orderBy: 'mystery_number',
      );

      return maps.map((map) => _mapToMystery(map)).toList();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get mysteries by type: $type', e, stackTrace);
      return [];
    }
  }

  @override
  Future<RosaryMystery?> getMysteryById(String id) async {
    try {
      final db = await RosaryDatabase.instance.database;
      final maps = await db.query(
        'mysteries',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isNotEmpty) {
        return _mapToMystery(maps.first);
      }
      return null;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get mystery by id: $id', e, stackTrace);
      return null;
    }
  }

  @override
  Future<List<RosaryBead>> getBeads() async {
    try {
      final db = await RosaryDatabase.instance.database;
      final maps = await db.query('beads', orderBy: 'decade_position');

      return maps.map((map) => _mapToBead(map)).toList();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get all beads', e, stackTrace);
      return [];
    }
  }

  @override
  Future<List<RosaryBead>> getBeadsByType(String type) async {
    try {
      final db = await RosaryDatabase.instance.database;
      final maps = await db.query(
        'beads',
        where: 'type = ?',
        whereArgs: [type],
        orderBy: 'decade_position',
      );

      return maps.map((map) => _mapToBead(map)).toList();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get beads by type: $type', e, stackTrace);
      return [];
    }
  }

  @override
  Future<void> createMystery(RosaryMystery mystery) async {
    try {
      final db = await RosaryDatabase.instance.database;
      await db.insert('mysteries', _mysteryToMap(mystery));
    } catch (e, stackTrace) {
      AppLogger.error('Failed to create mystery', e, stackTrace);
    }
  }

  @override
  Future<void> createBead(RosaryBead bead) async {
    try {
      final db = await RosaryDatabase.instance.database;
      await db.insert('beads', _beadToMap(bead));
    } catch (e, stackTrace) {
      AppLogger.error('Failed to create bead', e, stackTrace);
    }
  }

  @override
  Future<void> updateMystery(RosaryMystery mystery) async {
    try {
      final db = await RosaryDatabase.instance.database;
      await db.update(
        'mysteries',
        _mysteryToMap(mystery),
        where: 'id = ?',
        whereArgs: [mystery.id],
      );
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update mystery', e, stackTrace);
    }
  }

  @override
  Future<void> updateBead(RosaryBead bead) async {
    try {
      final db = await RosaryDatabase.instance.database;
      await db.update(
        'beads',
        _beadToMap(bead),
        where: 'id = ?',
        whereArgs: [bead.id],
      );
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update bead', e, stackTrace);
    }
  }

  @override
  Future<void> deleteMystery(String id) async {
    try {
      final db = await RosaryDatabase.instance.database;
      await db.delete('mysteries', where: 'id = ?', whereArgs: [id]);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete mystery', e, stackTrace);
    }
  }

  @override
  Future<void> deleteBead(String id) async {
    try {
      final db = await RosaryDatabase.instance.database;
      await db.delete('beads', where: 'id = ?', whereArgs: [id]);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete bead', e, stackTrace);
    }
  }

  @override
  Future<void> clearAllData() async {
    try {
      final db = await RosaryDatabase.instance.database;
      await db.delete('mysteries');
      await db.delete('beads');
      await db.delete('sessions');
      await db.delete('settings');
      await db.delete('statistics');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clear all data', e, stackTrace);
    }
  }

  @override
  Future<bool> isDataSeeded() async {
    try {
      final db = await RosaryDatabase.instance.database;
      final result = await db.query('mysteries', limit: 1);
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> seedInitialData() async {
    // Data is seeded automatically in database initialization
  }

  RosaryMystery _mapToMystery(Map<String, dynamic> map) {
    return RosaryMystery(
      id: map['id'] as String,
      type: MysteryType.fromString(map['type'] as String),
      mysteryNumber: map['mystery_number'] as int,
      title: map['title'] as String,
      description: map['description'] as String,
      scriptureText: map['scripture_text'] as String,
      meditationText: map['meditation_text'] as String,
      imagePath: map['image_path'] as String?,
    );
  }

  RosaryBead _mapToBead(Map<String, dynamic> map) {
    return RosaryBead(
      id: map['id'] as String,
      type: BeadType.fromString(map['type'] as String),
      decadePosition: map['decade_position'] as int,
      prayerText: map['prayer_text'] as String,
      audioUrl: map['audio_url'] as String?,
    );
  }

  Map<String, dynamic> _mysteryToMap(RosaryMystery mystery) {
    return {
      'id': mystery.id,
      'type': mystery.type.value,
      'mystery_number': mystery.mysteryNumber,
      'title': mystery.title,
      'description': mystery.description,
      'scripture_text': mystery.scriptureText,
      'meditation_text': mystery.meditationText,
      'image_path': mystery.imagePath,
    };
  }

  Map<String, dynamic> _beadToMap(RosaryBead bead) {
    return {
      'id': bead.id,
      'type': bead.type.value,
      'decade_position': bead.decadePosition,
      'prayer_text': bead.prayerText,
      'audio_url': bead.audioUrl,
    };
  }
}
