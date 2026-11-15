/// The pinned historySource source-class registry (modern-saint-histories
/// plan Task 1).
///
/// Every authored history carries `historySource = '<class> <url>'` where
/// `<class>` names the contract source of the grounding text. Two classes
/// ship:
///
///   * `catholic-encyclopedia-1907` — public domain, via newadvent.org;
///   * `wikipedia` — CC BY-SA 4.0, https://en.wikipedia.org article URLs.
///
/// The map value is the EXACT attribution copy the detail screen renders
/// (pinned by `test/utils/history_source_test.dart`); the app imports this
/// registry rather than re-stating the strings.
library;

/// Source class → exact, screen-rendered attribution line.
const Map<String, String> sourceClasses = <String, String>{
  'catholic-encyclopedia-1907': 'Adapted from the Catholic Encyclopedia (1907–12)',
  'wikipedia': 'Adapted from Wikipedia (CC BY-SA 4.0)',
};

/// Source class → short article-text label used inside authoring and
/// cross-check prompts (NOT the screen attribution copy).
const Map<String, String> sourceTextLabels = <String, String>{
  'catholic-encyclopedia-1907': 'Catholic Encyclopedia, 1907–12',
  'wikipedia': 'Wikipedia article (CC BY-SA 4.0)',
};

/// Per-class URL shape restricting the URL part after the class prefix.
const Map<String, String> _sourceUrlPatterns = <String, String>{
  'catholic-encyclopedia-1907': r'https?://www\.newadvent\.org/cathen/\S+',
  'wikipedia': r'https://en\.wikipedia\.org/wiki/\S+',
};

/// Grounding directory (relative to the package root) per source class.
const Map<String, String> _sourceGroundingDirs = <String, String>{
  'catholic-encyclopedia-1907': 'data/grounding',
  'wikipedia': 'data/grounding_wikipedia',
};

/// A `historySource` pattern restricted to [classes]; every class must be a
/// registry key.
RegExp historySourcePatternFor(Iterable<String> classes) {
  final List<String> parts = <String>[
    for (final String cls in classes)
      '${RegExp.escape(cls)} ${_sourceUrlPatterns[_require(cls)]}',
  ];
  return RegExp('^(?:${parts.join('|')})\$');
}

/// The attribution line for a `<class> <url>` historySource string; throws
/// `ArgumentError` on an unknown class.
String attributionFor(String historySource) {
  final int space = historySource.indexOf(' ');
  final String cls = space <= 0 ? '' : historySource.substring(0, space);
  final String? attribution = sourceClasses[cls];
  if (attribution == null) {
    throw ArgumentError.value(
      historySource,
      'historySource',
      'unknown history source class: ${cls.isEmpty ? '<none>' : cls}',
    );
  }
  return attribution;
}

/// The grounding directory for [sourceClass]; throws `ArgumentError` on an
/// unknown class.
String groundingDirFor(String sourceClass) =>
    _sourceGroundingDirs[_require(sourceClass)]!;

String _require(String cls) {
  if (!_sourceUrlPatterns.containsKey(cls)) {
    throw ArgumentError.value(cls, 'sourceClass', 'unknown class');
  }
  return cls;
}
