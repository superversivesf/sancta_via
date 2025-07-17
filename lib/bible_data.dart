/// A pure Dart package for Catholic Bible texts with search and lookup capabilities.
///
/// This package provides access to multiple Catholic Bible translations including:
/// - Catholic Public Domain Version (CPDV)
/// - Douay-Rheims Catholic (DRC)
/// - World English Bible Catholic (WEB-C)
///
/// Features:
/// - Fast book, chapter, and verse lookups
/// - Full-text search across translations
/// - Support for verse ranges
/// - Standardized book name mapping
/// - Memory-efficient caching
library bible_data;

export 'src/models/bible_translation.dart';
export 'src/models/bible_book.dart';
export 'src/models/bible_chapter.dart';
export 'src/models/bible_verse.dart';
export 'src/models/bible.dart';
export 'src/models/scripture_reference.dart';

export 'src/services/bible_loader.dart';
export 'src/services/sqlite_bible_loader.dart';
export 'src/services/optimized_sqlite_bible_loader.dart';
export 'src/services/bible_search_service.dart';
export 'src/services/bible_service.dart';
export 'src/services/optimized_bible_service.dart';

export 'src/utils/book_mapping.dart';
export 'src/utils/reference_parser.dart';
export 'src/utils/book_name_normalizer.dart';
