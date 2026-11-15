/// Saint dataset, SQLite store, and search for Sancta Via apps.
///
/// This package provides the saint models, feast-day keys, search
/// normalization, and the shared [SaintLogger]; the database store and
/// search APIs grow in later tasks.
library saint_data;

export 'src/db/saints_schema.dart';
export 'src/models/saint.dart';
export 'src/models/saint_category.dart';
export 'src/models/saint_search_result.dart';
export 'src/services/saint_feast_service.dart';
export 'src/services/saint_repository.dart';
export 'src/services/saints_db_loader.dart';
export 'src/utils/history_source.dart';
export 'src/utils/logger.dart';
export 'src/utils/normalization.dart';
