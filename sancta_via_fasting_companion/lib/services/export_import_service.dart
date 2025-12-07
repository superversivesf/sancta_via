import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/fast_session.dart';
import '../repositories/fasting_repository.dart';
import '../services/achievement_service.dart';
import '../utils/app_logger.dart';

/// Service for exporting and importing fasting data
class ExportImportService {
  final FastingRepository repository;
  final AchievementService achievementService;

  ExportImportService({
    required this.repository,
    required this.achievementService,
  });

  // ==================== Export ====================

  /// Export all fasting data to JSON format (complete backup)
  Future<ExportResult> exportToJSON() async {
    try {
      AppLogger.info('Starting JSON export...', 'ExportImportService');

      // Get all sessions
      final sessions = await repository.getFastHistory();

      // Get all earned achievements
      final achievements = await achievementService.getEarnedAchievements();

      // Create export data structure
      final exportData = {
        'version': '1.0',
        'exportDate': DateTime.now().toIso8601String(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'achievements': achievements.map((a) => {
          'id': a.achievementId,
          'earnedAt': a.earnedAt.toIso8601String(),
          'seen': a.seen,
        }).toList(),
        'stats': {
          'totalSessions': sessions.length,
          'totalAchievements': achievements.length,
        },
      };

      // Convert to JSON string
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // Save to file
      final fileName = 'sancta_via_fasting_backup_${_getDateStamp()}.json';
      final file = await _saveToFile(fileName, jsonString);

      AppLogger.info('JSON export successful: ${file.path}', 'ExportImportService');

      return ExportResult.success(
        file: file,
        format: ExportFormat.json,
        recordCount: sessions.length,
      );
    } catch (e, stack) {
      AppLogger.error('Error exporting to JSON', e, stack, 'ExportImportService');
      return ExportResult.error('Failed to export: ${e.toString()}');
    }
  }

  /// Export fasting sessions to CSV format (for spreadsheets)
  Future<ExportResult> exportToCSV() async {
    try {
      AppLogger.info('Starting CSV export...', 'ExportImportService');

      // Get all sessions
      final sessions = await repository.getFastHistory();

      if (sessions.isEmpty) {
        return ExportResult.error('No fasting sessions to export');
      }

      // Create CSV content
      final csvBuffer = StringBuffer();

      // Header row
      csvBuffer.writeln(
        'Session ID,Fast Type,Start Time,End Time,Duration (hours),Target Duration (hours),Status,Progress (%),Notes',
      );

      // Data rows
      for (final session in sessions) {
        final durationHours = session.elapsedDuration.inMinutes / 60.0;
        final targetHours = session.targetDurationMinutes / 60.0;
        final progress = (session.elapsedDuration.inMinutes / session.targetDurationMinutes * 100).clamp(0, 100);

        csvBuffer.writeln(
          '"${session.id}",'
          '"${await _getFastTypeName(session.fastTypeId)}",'
          '"${_formatDateTime(session.startTime)}",'
          '"${session.endTime != null ? _formatDateTime(session.endTime!) : 'In Progress'}",'
          '${durationHours.toStringAsFixed(2)},'
          '${targetHours.toStringAsFixed(2)},'
          '"${session.status.toString().split('.').last}",'
          '${progress.toStringAsFixed(1)},'
          '"${_escapeCsv(session.notes ?? '')}"',
        );
      }

      // Save to file
      final fileName = 'sancta_via_fasting_history_${_getDateStamp()}.csv';
      final file = await _saveToFile(fileName, csvBuffer.toString());

      AppLogger.info('CSV export successful: ${file.path}', 'ExportImportService');

      return ExportResult.success(
        file: file,
        format: ExportFormat.csv,
        recordCount: sessions.length,
      );
    } catch (e, stack) {
      AppLogger.error('Error exporting to CSV', e, stack, 'ExportImportService');
      return ExportResult.error('Failed to export: ${e.toString()}');
    }
  }

  /// Share the exported file
  Future<bool> shareExport(File file, ExportFormat format) async {
    try {
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Sancta Via Fasting ${format == ExportFormat.json ? 'Backup' : 'History'}',
        text: format == ExportFormat.json
            ? 'My fasting data backup from Sancta Via Fasting Companion'
            : 'My fasting history from Sancta Via Fasting Companion',
      );

      return result.status == ShareResultStatus.success;
    } catch (e, stack) {
      AppLogger.error('Error sharing export', e, stack, 'ExportImportService');
      return false;
    }
  }

  // ==================== Import ====================

  /// Import fasting data from JSON file
  Future<ImportResult> importFromJSON() async {
    try {
      AppLogger.info('Starting JSON import...', 'ExportImportService');

      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult.cancelled();
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        return ImportResult.error('Could not read file path');
      }

      // Read file
      final file = File(filePath);
      final jsonString = await file.readAsString();

      // Parse JSON
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate format
      if (!data.containsKey('version') || !data.containsKey('sessions')) {
        return ImportResult.error('Invalid backup file format');
      }

      // Extract sessions
      final sessionsData = data['sessions'] as List<dynamic>;
      final sessions = sessionsData
          .map((s) => FastSession.fromJson(s as Map<String, dynamic>))
          .toList();

      // Import sessions
      int importedCount = 0;
      for (final session in sessions) {
        try {
          await repository.importSession(session);
          importedCount++;
        } catch (e) {
          AppLogger.warning(
            'Failed to import session ${session.id}: $e',
            'ExportImportService',
          );
        }
      }

      // Extract and import achievements if present
      int achievementsImported = 0;
      if (data.containsKey('achievements')) {
        final achievementsData = data['achievements'] as List<dynamic>;
        for (final achData in achievementsData) {
          try {
            await achievementService.importEarnedAchievement(
              achData['id'] as String,
              DateTime.parse(achData['earnedAt'] as String),
              achData['seen'] as bool? ?? false,
            );
            achievementsImported++;
          } catch (e) {
            AppLogger.warning(
              'Failed to import achievement: $e',
              'ExportImportService',
            );
          }
        }
      }

      AppLogger.info(
        'JSON import successful: $importedCount sessions, $achievementsImported achievements',
        'ExportImportService',
      );

      return ImportResult.success(
        sessionsImported: importedCount,
        achievementsImported: achievementsImported,
      );
    } catch (e, stack) {
      AppLogger.error('Error importing from JSON', e, stack, 'ExportImportService');
      return ImportResult.error('Failed to import: ${e.toString()}');
    }
  }

  // ==================== Helper Methods ====================

  /// Save content to a file in the temp directory
  Future<File> _saveToFile(String fileName, String content) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(content);
    return file;
  }

  /// Get fast type name by ID
  Future<String> _getFastTypeName(String fastTypeId) async {
    final fastType = await repository.getFastTypeById(fastTypeId);
    return fastType?.name ?? 'Unknown';
  }

  /// Format DateTime for CSV
  String _formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }

  /// Escape CSV special characters
  String _escapeCsv(String value) {
    if (value.contains('"')) {
      return value.replaceAll('"', '""');
    }
    return value;
  }

  /// Get date stamp for file names
  String _getDateStamp() {
    return DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());
  }
}

// ==================== Result Classes ====================

enum ExportFormat { json, csv }

class ExportResult {
  final bool success;
  final File? file;
  final ExportFormat? format;
  final int? recordCount;
  final String? errorMessage;

  ExportResult._({
    required this.success,
    this.file,
    this.format,
    this.recordCount,
    this.errorMessage,
  });

  factory ExportResult.success({
    required File file,
    required ExportFormat format,
    required int recordCount,
  }) {
    return ExportResult._(
      success: true,
      file: file,
      format: format,
      recordCount: recordCount,
    );
  }

  factory ExportResult.error(String message) {
    return ExportResult._(
      success: false,
      errorMessage: message,
    );
  }
}

class ImportResult {
  final bool success;
  final bool cancelled;
  final int? sessionsImported;
  final int? achievementsImported;
  final String? errorMessage;

  ImportResult._({
    required this.success,
    required this.cancelled,
    this.sessionsImported,
    this.achievementsImported,
    this.errorMessage,
  });

  factory ImportResult.success({
    required int sessionsImported,
    required int achievementsImported,
  }) {
    return ImportResult._(
      success: true,
      cancelled: false,
      sessionsImported: sessionsImported,
      achievementsImported: achievementsImported,
    );
  }

  factory ImportResult.error(String message) {
    return ImportResult._(
      success: false,
      cancelled: false,
      errorMessage: message,
    );
  }

  factory ImportResult.cancelled() {
    return ImportResult._(
      success: false,
      cancelled: true,
    );
  }
}
