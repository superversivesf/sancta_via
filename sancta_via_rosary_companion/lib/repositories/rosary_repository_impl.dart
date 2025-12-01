import '../database/rosary_database.dart';
import '../models/rosary_mystery.dart';
import '../models/rosary_bead.dart';
import '../models/bead_type.dart';
import '../models/mystery_type.dart';
import '../utils/logger.dart';
import 'rosary_repository.dart';

class RosaryRepositoryImpl implements RosaryRepository {
  RosaryRepositoryImpl();

  @override
  Future<List<RosaryMystery>> getAllMysteries() async {
    try {
      final db = await RosaryDatabase.database;
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
      final db = await RosaryDatabase.database;
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
      final db = await RosaryDatabase.database;
      final maps = await db.query(
        'mysteries',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty) return null;
      return _mapToMystery(maps.first);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get mystery by id: $id', e, stackTrace);
      return null;
    }
  }

  @override
  Future<List<RosaryBead>> getBeads() async {
    try {
      final db = await RosaryDatabase.database;
      final maps = await db.query('beads');

      return maps.map((map) => _mapToBead(map)).toList();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get beads', e, stackTrace);
      return [];
    }
  }

  @override
  Future<List<RosaryBead>> getBeadsByType(String type) async {
    try {
      final db = await RosaryDatabase.database;
      final maps = await db.query(
        'beads',
        where: 'type = ?',
        whereArgs: [type],
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
      final db = await RosaryDatabase.database;
      await db.insert('mysteries', _mapFromMystery(mystery));
      AppLogger.debug('Mystery created: ${mystery.id}');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to create mystery: ${mystery.id}', e, stackTrace);
    }
  }

  @override
  Future<void> createBead(RosaryBead bead) async {
    try {
      final db = await RosaryDatabase.database;
      await db.insert('beads', _mapFromBead(bead));
      AppLogger.debug('Bead created: ${bead.id}');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to create bead: ${bead.id}', e, stackTrace);
    }
  }

  @override
  Future<void> updateMystery(RosaryMystery mystery) async {
    try {
      final db = await RosaryDatabase.database;
      await db.update(
        'mysteries',
        _mapFromMystery(mystery),
        where: 'id = ?',
        whereArgs: [mystery.id],
      );
      AppLogger.debug('Mystery updated: ${mystery.id}');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update mystery: ${mystery.id}', e, stackTrace);
    }
  }

  @override
  Future<void> updateBead(RosaryBead bead) async {
    try {
      final db = await RosaryDatabase.database;
      await db.update(
        'beads',
        _mapFromBead(bead),
        where: 'id = ?',
        whereArgs: [bead.id],
      );
      AppLogger.debug('Bead updated: ${bead.id}');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update bead: ${bead.id}', e, stackTrace);
    }
  }

  @override
  Future<void> deleteMystery(String id) async {
    try {
      final db = await RosaryDatabase.database;
      await db.delete(
        'mysteries',
        where: 'id = ?',
        whereArgs: [id],
      );
      AppLogger.debug('Mystery deleted: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete mystery: $id', e, stackTrace);
    }
  }

  @override
  Future<void> deleteBead(String id) async {
    try {
      final db = await RosaryDatabase.database;
      await db.delete(
        'beads',
        where: 'id = ?',
        whereArgs: [id],
      );
      AppLogger.debug('Bead deleted: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete bead: $id', e, stackTrace);
    }
  }

  @override
  Future<void> clearAllData() async {
    try {
      final db = await RosaryDatabase.database;
      await db.delete('mysteries');
      await db.delete('beads');
      AppLogger.debug('All rosary data cleared');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clear all data', e, stackTrace);
    }
  }

  @override
  Future<bool> isDataSeeded() async {
    try {
      final db = await RosaryDatabase.database;
      final mysteryCount = await db.rawQuery('SELECT COUNT(*) FROM mysteries');
      final beadCount = await db.rawQuery('SELECT COUNT(*) FROM beads');

      final mysteryTotal = mysteryCount.isNotEmpty ?
          mysteryCount.first.values.first as int :
          0;
      final beadTotal = beadCount.isNotEmpty ?
          beadCount.first.values.first as int :
          0;

      return mysteryTotal > 0 && beadTotal > 0;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to check if data is seeded', e, stackTrace);
      return false;
    }
  }

  @override
  Future<void> seedInitialData() async {
    try {
      if (await isDataSeeded()) {
        AppLogger.debug('Data already seeded, skipping');
        return;
      }

      await RosaryDatabase.seedInitialData();
      AppLogger.debug('Initial data seeded successfully');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to seed initial data', e, stackTrace);
    }
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
    );
  }

  Map<String, dynamic> _mapFromMystery(RosaryMystery mystery) {
    return {
      'id': mystery.id,
      'type': mystery.type.value,
      'mystery_number': mystery.mysteryNumber,
      'title': mystery.title,
      'description': mystery.description,
      'scripture_text': mystery.scriptureText,
      'meditation_text': mystery.meditationText,
    };
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

  Map<String, dynamic> _mapFromBead(RosaryBead bead) {
    return {
      'id': bead.id,
      'type': bead.type.value,
      'decade_position': bead.decadePosition,
      'prayer_text': bead.prayerText,
      'audio_url': bead.audioUrl,
    };
  }
}