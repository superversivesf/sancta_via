/// Riverpod providers for the bible_data package with reactive state management
///
/// This library provides Flutter Riverpod integration for the bible_data package,
/// offering reactive state management, automatic caching, and simplified data access.
///
/// ## Basic Usage
///
/// ```dart
/// import 'package:flutter_riverpod/flutter_riverpod.dart';
/// import 'package:bible_data_riverpod/bible_data_riverpod.dart';
///
/// class MyWidget extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final scripture = ref.watch(scriptureProvider('John 3:16'));
///
///     return scripture.when(
///       data: (content) => Text(content.text),
///       loading: () => CircularProgressIndicator(),
///       error: (error, stack) => Text('Error: $error'),
///     );
///   }
/// }
/// ```
library;

// Main exports
export 'src/providers/bible_providers.dart';
export 'src/providers/scripture_providers.dart';
export 'src/providers/search_providers.dart';
export 'src/providers/settings_providers.dart';

// Re-export bible_data models for convenience
export 'package:bible_data/bible_data.dart';
