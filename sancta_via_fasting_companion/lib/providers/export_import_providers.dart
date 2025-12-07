import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/export_import_service.dart';
import 'achievement_providers.dart';
import 'fast_type_providers.dart';

/// Provider for export/import service
final exportImportServiceProvider = Provider<ExportImportService>((ref) {
  final repository = ref.watch(fastingRepositoryProvider);
  final achievementService = ref.watch(achievementServiceProvider);

  return ExportImportService(
    repository: repository,
    achievementService: achievementService,
  );
});
