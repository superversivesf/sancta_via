import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import '../models/examination_model.dart';
import '../models/examination_session_model.dart';
import '../models/user_preferences_model.dart';
import '../data/examinations.dart';
import '../../../utils/logger.dart';
import '../../../utils/error_handler.dart';
import '../../../config/constants.dart';
import '../../../services/secure_storage_service.dart';

class ExaminationMetadata {
  final String id;
  final String title;
  final String description;
  final String source;
  final String targetAudience;
  final String fileName;

  ExaminationMetadata({
    required this.id,
    required this.title,
    required this.description,
    required this.source,
    required this.targetAudience,
    required this.fileName,
  });

  factory ExaminationMetadata.fromJson(Map<String, dynamic> json) {
    return ExaminationMetadata(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      source: json['source'],
      targetAudience: json['target_audience'],
      fileName: json['file_name'],
    );
  }
}

class ExaminationRepository {
  static const String _examinationsFolder = 'examinations';
  static const String _metadataFileName = AppConstants.examinationsMetadataFile;
  static const String _versionKey = 'examinations_version';

  // Get metadata for all available examinations
  Future<List<ExaminationMetadata>> getExaminationsMetadata() async {
    try {
      // Try to load from app documents directory first (for updated files)
      final appDir = await getApplicationDocumentsDirectory();
      final metadataFile = File('${appDir.path}/$_examinationsFolder/$_metadataFileName');

      if (await metadataFile.exists()) {
        // Load from local storage (might be an updated version)
        final jsonString = await metadataFile.readAsString();
        return _parseMetadata(jsonString);
      } else {
        // Load from bundled assets
        final jsonString = await rootBundle.loadString('assets/$_examinationsFolder/$_metadataFileName');
        return _parseMetadata(jsonString);
      }
    } catch (e) {
      // Log error
      AppLogger.error('Error loading examinations metadata', e, null, 'EXAM');

      // Return empty list on error
      return [];
    }
  }

  // Parse metadata from JSON string
  List<ExaminationMetadata> _parseMetadata(String jsonString) {
    final Map<String, dynamic> jsonData = json.decode(jsonString);
    final List<dynamic> examinationsJson = jsonData['examinations'];

    // Save version for future updates
    _saveCurrentVersion(jsonData['version']);

    return examinationsJson.map((json) => ExaminationMetadata.fromJson(json)).toList();
  }

  // Save current version to SharedPreferences
  Future<void> _saveCurrentVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_versionKey, version);
  }

  // Get all available examinations (full data)
  Future<List<ExaminationModel>> getExaminations() async {
    try {
      final metadataList = await getExaminationsMetadata();
      final List<ExaminationModel> examinations = [];

      for (var metadata in metadataList) {
        final examination = await getExaminationById(metadata.id);
        if (examination != null) {
          examinations.add(examination);
        }
      }

      // If no examinations loaded from assets, use sample data
      if (examinations.isEmpty) {
        AppLogger.examination('No examinations loaded from assets, using sample data');
        final sampleData = await _getSampleExaminations();
        return sampleData;
      }

      return examinations;
    } catch (e) {
      AppLogger.error('Error loading examinations, falling back to sample data', e, null, 'EXAM');
      return await _getSampleExaminations();
    }
  }

  // Get sample examinations as fallback
  Future<List<ExaminationModel>> _getSampleExaminations() async {
    AppLogger.examination('Using sample examinations data');
    return sampleExaminations;
  }

  // Get examination by ID
  Future<ExaminationModel?> getExaminationById(String id) async {
    AppLogger.repository('Loading examination by ID: $id');
    try {
      // First try to find metadata for this examination
      final metadataList = await getExaminationsMetadata();
      AppLogger.repository('Found ${metadataList.length} examination metadata entries');
      
      final metadata = metadataList.firstWhere(
        (meta) => meta.id == id,
        orElse: () => throw DataException('Examination not found: $id'),
      );
      
      AppLogger.repository('Found metadata for examination $id: ${metadata.fileName}');

      // Try to load from app documents directory first (for updated files)
      final appDir = await getApplicationDocumentsDirectory();
      final examinationFile = File('${appDir.path}/$_examinationsFolder/${metadata.fileName}');

      String jsonString;
      if (await examinationFile.exists()) {
        // Load from local storage (might be an updated version)
        AppLogger.repository('Loading examination from local storage: ${examinationFile.path}');
        jsonString = await examinationFile.readAsString();
      } else {
        // Load from bundled assets
        AppLogger.repository('Loading examination from bundled assets: assets/$_examinationsFolder/${metadata.fileName}');
        jsonString = await rootBundle.loadString('assets/$_examinationsFolder/${metadata.fileName}');
      }

      // Parse JSON
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      AppLogger.repository('Successfully parsed JSON for examination $id');
      return ExaminationModel.fromJson(jsonData);
      
    } catch (e, stackTrace) {
      if (e is DataException) {
        rethrow; // Re-throw our custom exceptions
      }
      
      // Log and wrap unexpected errors
      AppLogger.error('Error loading examination $id', e, stackTrace, 'REPO');
      throw DataException('Failed to load examination: $id');
    }
  }

  // Preferences storage key
  static const String _preferencesKey = AppConstants.examinationPreferencesKey;

  // Get user preferences
  Future<ExaminationPreferences> getUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_preferencesKey);

    if (jsonString == null) {
      // Return default preferences if none are saved
      return ExaminationPreferences();
    }

    return ExaminationPreferences.fromJson(json.decode(jsonString));
  }

  // Save user preferences
  Future<void> saveUserPreferences(ExaminationPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferencesKey, json.encode(preferences.toJson()));
  }

  // Toggle favorite status for an examination
  Future<ExaminationPreferences> toggleFavorite(String examinationId) async {
    final preferences = await getUserPreferences();

    final List<String> updatedFavorites = List.from(preferences.favoriteExaminationIds);
    if (updatedFavorites.contains(examinationId)) {
      updatedFavorites.remove(examinationId);
    } else {
      updatedFavorites.add(examinationId);
    }

    final updatedPreferences = preferences.copyWith(
      favoriteExaminationIds: updatedFavorites,
    );

    await saveUserPreferences(updatedPreferences);
    return updatedPreferences;
  }

  // Set default examination
  Future<ExaminationPreferences> setDefaultExamination(String? examinationId) async {
    final preferences = await getUserPreferences();

    final updatedPreferences = preferences.copyWith(
      defaultExaminationId: examinationId,
    );

    await saveUserPreferences(updatedPreferences);
    return updatedPreferences;
  }

  // Check if updates are available (stub for future implementation)
  Future<bool> checkForUpdates() async {
    // TODO: Implement API call to check for updates
    return false;
  }

  // Download updated examinations (stub for future implementation)
  Future<bool> downloadUpdates() async {
    try {
      // TODO: Implement download functionality
      final appDir = await getApplicationDocumentsDirectory();
      final examinationsDir = Directory('${appDir.path}/$_examinationsFolder');
      if (!await examinationsDir.exists()) {
        await examinationsDir.create(recursive: true);
      }

      return true;
    } catch (e) {
      AppLogger.error('Error downloading updates', e, null, 'EXAM');
      return false;
    }
  }

  // Save active session (securely)
  Future<void> saveActiveSession(ExaminationSession session) async {
    AppLogger.repository('Saving active session: ${session.id}');
    
    try {
      final jsonData = jsonEncode(session.toJson());
      await SecureStorageService.saveActiveExaminationSession(jsonData);
      AppLogger.repository('Session saved to secure storage');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save examination session', e, stackTrace, 'REPO');
      throw DataException('Failed to save examination session');
    }
  }

  // Get active session (if exists)
  Future<ExaminationSession?> getActiveSession() async {
    AppLogger.repository('Attempting to get active session');
    
    try {
      final jsonData = await SecureStorageService.getActiveExaminationSession();
      
      if (jsonData == null) {
        AppLogger.repository('No active session found in secure storage');
        return null;
      }
      
      AppLogger.repository('Found active session data, length: ${jsonData.length}');
      final session = ExaminationSession.fromJson(jsonDecode(jsonData));
      AppLogger.repository('Successfully parsed active session with ID: ${session.id}');
      return session;
      
    } catch (e, stackTrace) {
      AppLogger.error('Error parsing active session', e, stackTrace, 'REPO');
      throw DataException('Failed to load active examination session');
    }
  }

  // Complete and archive a session
  Future<void> completeSession(ExaminationSession session) async {
    AppLogger.repository('Repository completing session: ${session.id}');
    
    try {
      // Mark as completed
      final completedSession = session.copyWith(isCompleted: true);
      
      // Get previously completed sessions from secure storage
      final String? existingCompletedData = await SecureStorageService.getCompletedExaminations();
      List<dynamic> completedSessionsList = [];
      
      if (existingCompletedData != null) {
        try {
          completedSessionsList = jsonDecode(existingCompletedData);
        } catch (e) {
          AppLogger.warning('Failed to parse existing completed sessions, starting fresh', 'REPO');
          completedSessionsList = [];
        }
      }

      // Add this session to the list
      completedSessionsList.add(completedSession.toJson());

      // Save all completed sessions back to secure storage
      final updatedCompletedData = jsonEncode(completedSessionsList);
      await SecureStorageService.saveCompletedExaminations(updatedCompletedData);

      // Clear active session
      await SecureStorageService.clearActiveExaminationSession();
      AppLogger.repository('Deleted active session from secure storage');
      
    } catch (e, stackTrace) {
      AppLogger.error('Failed to complete examination session', e, stackTrace, 'REPO');
      throw DataException('Failed to complete examination session');
    }
  }

  // Get completed sessions from secure storage
  Future<List<ExaminationSession>> getCompletedSessions() async {
    try {
      final completedData = await SecureStorageService.getCompletedExaminations();
      
      if (completedData == null) {
        AppLogger.repository('No completed sessions found');
        return [];
      }

      final List<dynamic> completedSessionsList = jsonDecode(completedData);
      final List<ExaminationSession> completedSessions = [];

      for (final sessionJson in completedSessionsList) {
        try {
          final session = ExaminationSession.fromJson(sessionJson);
          completedSessions.add(session);
        } catch (e) {
          AppLogger.error('Error parsing completed session', e, null, 'REPO');
          // Skip corrupted sessions rather than failing entirely
        }
      }

      // Sort by most recent first
      completedSessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      AppLogger.repository('Loaded ${completedSessions.length} completed sessions');
      return completedSessions;
      
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load completed sessions', e, stackTrace, 'REPO');
      return []; // Return empty list on error rather than throwing
    }
  }

  // Delete specific session data (after confession)
  Future<void> deleteSession(String sessionId) async {
    try {
      AppLogger.repository('Deleting session: $sessionId');
      
      // Get current completed sessions
      final completedData = await SecureStorageService.getCompletedExaminations();
      if (completedData == null) {
        AppLogger.repository('No completed sessions to delete from');
        return;
      }

      final List<dynamic> completedSessionsList = jsonDecode(completedData);
      
      // Remove the session with matching ID
      completedSessionsList.removeWhere((sessionJson) {
        try {
          return sessionJson['id'] == sessionId;
        } catch (e) {
          return false; // Keep sessions we can't parse
        }
      });

      // Save the updated list back
      final updatedCompletedData = jsonEncode(completedSessionsList);
      await SecureStorageService.saveCompletedExaminations(updatedCompletedData);
      
      AppLogger.repository('Successfully deleted session $sessionId');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete session $sessionId', e, stackTrace, 'REPO');
      throw DataException('Failed to delete examination session');
    }
  }

  // Delete all sessions (clear everything)
  Future<void> deleteAllSessions() async {
    try {
      AppLogger.repository('Deleting all examination sessions');
      
      // Clear active session
      await SecureStorageService.clearActiveExaminationSession();
      
      // Clear all completed sessions
      await SecureStorageService.saveCompletedExaminations('[]');
      
      AppLogger.repository('Successfully deleted all examination sessions');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete all sessions', e, stackTrace, 'REPO');
      throw DataException('Failed to delete all examination sessions');
    }
  }
}
