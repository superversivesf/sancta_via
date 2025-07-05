import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/novena.dart';
import '../../../utils/logger.dart';

/// Simple repository for loading novena data from JSON assets
/// This is a clean starting point for your new implementation
class NovenaRepository {
  static const String _assetBase = 'assets/novenas';
  
  /// Load novena metadata from assets
  Future<List<NovenaMetadata>> loadNovenaMetadata() async {
    try {
      final metadataJson = await rootBundle.loadString('$_assetBase/novenas_metadata.json');
      final metadataData = json.decode(metadataJson) as Map<String, dynamic>;
      final novenasList = metadataData['novenas'] as List<dynamic>;
      
      final metadata = novenasList
          .map((novenaJson) => NovenaMetadata.fromJson(novenaJson as Map<String, dynamic>))
          .toList();
      
      return metadata;
    } catch (e) {
      AppLogger.error('Failed to load novena metadata', e, null, 'NOVENA_REPO');
      throw Exception('Failed to load novena metadata: $e');
    }
  }

  /// Load a specific novena by ID
  Future<Novena> loadNovena(String novenaId) async {
    try {
      // Get metadata to find the file name
      final metadata = await loadNovenaMetadata();
      
      final novenaMetadata = metadata.firstWhere(
        (meta) => meta.id == novenaId,
        orElse: () {
          final availableIds = metadata.map((meta) => meta.id).join(', ');
          AppLogger.error('Novena not found: $novenaId. Available IDs: $availableIds', null, null, 'NOVENA_REPO');
          throw ArgumentError('Novena not found: $novenaId');
        },
      );

      // Load the novena content
      final assetPath = '$_assetBase/${novenaMetadata.fileName}';
      final novenaJson = await rootBundle.loadString(assetPath);
      final novenaData = json.decode(novenaJson) as Map<String, dynamic>;
      return Novena.fromJson(novenaData);
    } catch (e) {
      AppLogger.error('Failed to load novena "$novenaId"', e, null, 'NOVENA_REPO');
      throw Exception('Failed to load novena $novenaId: $e');
    }
  }
}
