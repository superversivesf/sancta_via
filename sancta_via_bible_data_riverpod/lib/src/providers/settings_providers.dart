import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bible_data/bible_data.dart';

/// Provider for the selected Bible translation
final selectedBibleTranslationProvider = StateProvider<BibleTranslation>((ref) {
  return BibleTranslation.cpdv; // Default to Catholic Public Domain Version
});

/// Provider for Bible reading preferences
final bibleReadingPreferencesProvider =
    StateNotifierProvider<
      BibleReadingPreferencesNotifier,
      BibleReadingPreferences
    >((ref) {
      return BibleReadingPreferencesNotifier();
    });

/// Bible reading preferences model
class BibleReadingPreferences {
  final BibleTranslation preferredTranslation;
  final double fontSize;
  final bool showVerseNumbers;
  final bool showChapterHeaders;
  final bool enableWordWrap;
  final String fontFamily;
  final double lineHeight;
  final bool darkMode;
  final bool enableParallelTranslations;
  final List<BibleTranslation> parallelTranslations;

  const BibleReadingPreferences({
    this.preferredTranslation = BibleTranslation.cpdv,
    this.fontSize = 16.0,
    this.showVerseNumbers = true,
    this.showChapterHeaders = true,
    this.enableWordWrap = true,
    this.fontFamily = 'System',
    this.lineHeight = 1.5,
    this.darkMode = false,
    this.enableParallelTranslations = false,
    this.parallelTranslations = const [],
  });

  BibleReadingPreferences copyWith({
    BibleTranslation? preferredTranslation,
    double? fontSize,
    bool? showVerseNumbers,
    bool? showChapterHeaders,
    bool? enableWordWrap,
    String? fontFamily,
    double? lineHeight,
    bool? darkMode,
    bool? enableParallelTranslations,
    List<BibleTranslation>? parallelTranslations,
  }) {
    return BibleReadingPreferences(
      preferredTranslation: preferredTranslation ?? this.preferredTranslation,
      fontSize: fontSize ?? this.fontSize,
      showVerseNumbers: showVerseNumbers ?? this.showVerseNumbers,
      showChapterHeaders: showChapterHeaders ?? this.showChapterHeaders,
      enableWordWrap: enableWordWrap ?? this.enableWordWrap,
      fontFamily: fontFamily ?? this.fontFamily,
      lineHeight: lineHeight ?? this.lineHeight,
      darkMode: darkMode ?? this.darkMode,
      enableParallelTranslations:
          enableParallelTranslations ?? this.enableParallelTranslations,
      parallelTranslations: parallelTranslations ?? this.parallelTranslations,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BibleReadingPreferences &&
            runtimeType == other.runtimeType &&
            preferredTranslation == other.preferredTranslation &&
            fontSize == other.fontSize &&
            showVerseNumbers == other.showVerseNumbers &&
            showChapterHeaders == other.showChapterHeaders &&
            enableWordWrap == other.enableWordWrap &&
            fontFamily == other.fontFamily &&
            lineHeight == other.lineHeight &&
            darkMode == other.darkMode &&
            enableParallelTranslations == other.enableParallelTranslations;
  }

  @override
  int get hashCode {
    return Object.hash(
      preferredTranslation,
      fontSize,
      showVerseNumbers,
      showChapterHeaders,
      enableWordWrap,
      fontFamily,
      lineHeight,
      darkMode,
      enableParallelTranslations,
    );
  }
}

/// StateNotifier for managing Bible reading preferences
class BibleReadingPreferencesNotifier
    extends StateNotifier<BibleReadingPreferences> {
  BibleReadingPreferencesNotifier() : super(const BibleReadingPreferences());

  /// Update preferred translation
  void updatePreferredTranslation(BibleTranslation translation) {
    state = state.copyWith(preferredTranslation: translation);
  }

  /// Update font size
  void updateFontSize(double fontSize) {
    state = state.copyWith(fontSize: fontSize);
  }

  /// Toggle verse numbers visibility
  void toggleVerseNumbers() {
    state = state.copyWith(showVerseNumbers: !state.showVerseNumbers);
  }

  /// Toggle chapter headers visibility
  void toggleChapterHeaders() {
    state = state.copyWith(showChapterHeaders: !state.showChapterHeaders);
  }

  /// Toggle word wrap
  void toggleWordWrap() {
    state = state.copyWith(enableWordWrap: !state.enableWordWrap);
  }

  /// Update font family
  void updateFontFamily(String fontFamily) {
    state = state.copyWith(fontFamily: fontFamily);
  }

  /// Update line height
  void updateLineHeight(double lineHeight) {
    state = state.copyWith(lineHeight: lineHeight);
  }

  /// Toggle dark mode
  void toggleDarkMode() {
    state = state.copyWith(darkMode: !state.darkMode);
  }

  /// Toggle parallel translations
  void toggleParallelTranslations() {
    state = state.copyWith(
      enableParallelTranslations: !state.enableParallelTranslations,
    );
  }

  /// Update parallel translations list
  void updateParallelTranslations(List<BibleTranslation> translations) {
    state = state.copyWith(parallelTranslations: translations);
  }

  /// Reset to defaults
  void resetToDefaults() {
    state = const BibleReadingPreferences();
  }

  /// Load preferences from storage (to be implemented by apps)
  void loadPreferences(BibleReadingPreferences preferences) {
    state = preferences;
  }
}

/// Search settings model
class SearchSettings {
  final bool caseSensitive;
  final bool wholeWords;
  final bool oldTestamentOnly;
  final bool newTestamentOnly;
  final int maxResults;
  final bool highlightResults;
  final bool groupByBook;

  const SearchSettings({
    this.caseSensitive = false,
    this.wholeWords = false,
    this.oldTestamentOnly = false,
    this.newTestamentOnly = false,
    this.maxResults = 50,
    this.highlightResults = true,
    this.groupByBook = false,
  });

  SearchSettings copyWith({
    bool? caseSensitive,
    bool? wholeWords,
    bool? oldTestamentOnly,
    bool? newTestamentOnly,
    int? maxResults,
    bool? highlightResults,
    bool? groupByBook,
  }) {
    return SearchSettings(
      caseSensitive: caseSensitive ?? this.caseSensitive,
      wholeWords: wholeWords ?? this.wholeWords,
      oldTestamentOnly: oldTestamentOnly ?? this.oldTestamentOnly,
      newTestamentOnly: newTestamentOnly ?? this.newTestamentOnly,
      maxResults: maxResults ?? this.maxResults,
      highlightResults: highlightResults ?? this.highlightResults,
      groupByBook: groupByBook ?? this.groupByBook,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SearchSettings &&
            runtimeType == other.runtimeType &&
            caseSensitive == other.caseSensitive &&
            wholeWords == other.wholeWords &&
            oldTestamentOnly == other.oldTestamentOnly &&
            newTestamentOnly == other.newTestamentOnly &&
            maxResults == other.maxResults &&
            highlightResults == other.highlightResults &&
            groupByBook == other.groupByBook;
  }

  @override
  int get hashCode {
    return Object.hash(
      caseSensitive,
      wholeWords,
      oldTestamentOnly,
      newTestamentOnly,
      maxResults,
      highlightResults,
      groupByBook,
    );
  }
}

/// Provider for search settings
final searchSettingsProvider =
    StateNotifierProvider<SearchSettingsNotifier, SearchSettings>((ref) {
      return SearchSettingsNotifier();
    });

/// StateNotifier for managing search settings
class SearchSettingsNotifier extends StateNotifier<SearchSettings> {
  SearchSettingsNotifier() : super(const SearchSettings());

  /// Toggle case sensitive search
  void toggleCaseSensitive() {
    state = state.copyWith(caseSensitive: !state.caseSensitive);
  }

  /// Toggle whole words search
  void toggleWholeWords() {
    state = state.copyWith(wholeWords: !state.wholeWords);
  }

  /// Toggle Old Testament only search
  void toggleOldTestamentOnly() {
    state = state.copyWith(
      oldTestamentOnly: !state.oldTestamentOnly,
      newTestamentOnly: false, // Disable NT if OT is enabled
    );
  }

  /// Toggle New Testament only search
  void toggleNewTestamentOnly() {
    state = state.copyWith(
      newTestamentOnly: !state.newTestamentOnly,
      oldTestamentOnly: false, // Disable OT if NT is enabled
    );
  }

  /// Update max results
  void updateMaxResults(int maxResults) {
    state = state.copyWith(maxResults: maxResults);
  }

  /// Toggle highlight results
  void toggleHighlightResults() {
    state = state.copyWith(highlightResults: !state.highlightResults);
  }

  /// Toggle group by book
  void toggleGroupByBook() {
    state = state.copyWith(groupByBook: !state.groupByBook);
  }

  /// Reset to defaults
  void resetToDefaults() {
    state = const SearchSettings();
  }

  /// Load settings from storage (to be implemented by apps)
  void loadSettings(SearchSettings settings) {
    state = settings;
  }
}

/// Provider for available font families
final availableFontFamiliesProvider = Provider<List<String>>((ref) {
  return [
    'System',
    'Serif',
    'Sans-Serif',
    'Monospace',
    'Georgia',
    'Times New Roman',
    'Arial',
    'Helvetica',
    'Roboto',
    'Open Sans',
  ];
});

/// Provider for font size options
final fontSizeOptionsProvider = Provider<List<double>>((ref) {
  return [12.0, 14.0, 16.0, 18.0, 20.0, 22.0, 24.0, 26.0, 28.0, 30.0];
});

/// Provider for line height options
final lineHeightOptionsProvider = Provider<List<double>>((ref) {
  return [1.0, 1.2, 1.4, 1.5, 1.6, 1.8, 2.0];
});

/// Provider for max results options
final maxResultsOptionsProvider = Provider<List<int>>((ref) {
  return [10, 25, 50, 100, 200, 500];
});
