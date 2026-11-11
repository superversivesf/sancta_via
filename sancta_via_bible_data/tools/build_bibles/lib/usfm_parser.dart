/// Rich USFM verse-parsing for the bible rebuild pipeline.
///
/// ONE parser with two consumers: `bin/validate_sources.dart` (real-verse
/// counting + reference-pin extraction for `expected_structure.json`) and
/// `bin/build_json.dart` (asset emission). Its stripping semantics are exactly
/// the proven reference extractor's, so the manifest's pinned reference verses
/// keep verifying.
///
/// Parsing rules:
/// - Chapters start at a line whose trimmed text is exactly `\c <n>`.
/// - Verses start at a `\v <label>` token (line-anchored, or inline after a
///   dropped footnote, as in `\v 1 … \f + …\f* \v 2 …`).
/// - Header lines (`\d`, `\s\d`, `\mt\d`, `\ms\d`, `\sp`, `\cl`, `\nb`, `\pc`,
///   `\mr`, `\b`) TERMINATE the running verse and are never appended to verse
///   text, with or without body text (all Psalm 119 acrostic `\d` lines land
///   here).
/// - Poetry (`\q`) and prose continuation lines belong to the running verse
///   until the next `\v`, `\c`, or header line.
/// - Text before the first `\v` of a chapter, and before the first chapter,
///   is ignored (titles, introductions, prologues).
/// - Footnote (`\f + …\f*`) and cross-reference (`\x + …\x*`) bodies are
///   dropped first (non-greedy, may span lines); `|key="value"` word
///   attributes are dropped; remaining backslash tags are dropped; the word
///   text and any suffix survive (`\w word|strong="…"\w*'s` → `word's`);
///   whitespace is collapsed and trimmed.
/// - A verse block that is empty after stripping a note-only `\v` (including
///   composite labels such as `\v 15-16`) produces NO verse. A composite or
///   non-integer label that DOES carry text throws (the build must fail
///   loudly rather than merge or silently drop real text).
/// - Duplicate chapter numbers, duplicate verse labels within a chapter, or a
///   leftover backslash in stripped text all throw.
library;

/// One parsed chapter: its number and its verses in reading order as
/// `(verse, text)` records.
class UsfmChapter {
  final int number;
  final List<(int, String)> verses;

  const UsfmChapter(this.number, this.verses);
}

/// Parses one whole USFM book file (`\id`-prefixed, `\c`/`\v`-structured)
/// into its chapter/verse structure.
List<UsfmChapter> parseUsfmBook(String usfmText) {
  final RegExp chapterPattern = RegExp(r'\\c (\d+)\s*$');
  final RegExp sectionHeaderPattern = RegExp(
    r'\\(s\d|d\b|mt\d|ms\d|sp\b|cl\b|nb\b|pc\b)\b',
  );
  final RegExp verseLabelPattern = RegExp(r'\\v (\S+)');

  final List<UsfmChapter> chapters = <UsfmChapter>[];
  final Set<int> seenChapters = <int>{};
  final Set<String> seenLabels = <String>{};

  int? chapter;
  String? blockLabel;
  List<String>? blockLines;

  void flush() {
    final String? label = blockLabel;
    blockLabel = null;
    if (label == null) {
      return;
    }
    final List<String> lines = blockLines!;
    final String text = _verseText(lines);
    if (text.isEmpty) {
      return; // note-only marker (footnote/cross-ref only): NO verse
    }
    final int? verseNumber = int.tryParse(label);
    if (verseNumber == null) {
      throw FormatException(
        'composite or non-integer verse label "$label" carries verse text '
        '"$text"; refusing to merge or silently drop it',
      );
    }
    chapters.last.verses.add((verseNumber, text));
  }

  void startBlock(String label, String firstLineContentAfterLabel) {
    final String marker = '$chapter/$label';
    if (seenLabels.contains(marker)) {
      throw FormatException('duplicate verse marker "$marker"');
    }
    seenLabels.add(marker);
    blockLabel = label;
    blockLines = <String>[firstLineContentAfterLabel];
  }

  for (final String rawLine in usfmText.split('\n')) {
    final String trimmed = rawLine.trim();

    final RegExpMatch? chapterMatch = chapterPattern.firstMatch(trimmed);
    if (chapterMatch != null) {
      flush();
      final int parsed = int.parse(chapterMatch.group(1)!);
      if (seenChapters.contains(parsed)) {
        throw FormatException('duplicate chapter "$parsed"');
      }
      seenChapters.add(parsed);
      chapter = parsed;
      chapters.add(UsfmChapter(parsed, <(int, String)>[]));
      continue;
    }
    if (chapter == null) {
      continue; // before the first chapter (masthead, `\mt` blocks, …)
    }

    if (trimmed.isEmpty) {
      continue; // blank lines neither advance nor terminate the verse
    }

    // Header lines terminate the running verse and are never verse text.
    if (sectionHeaderPattern.hasMatch(trimmed)) {
      flush();
      continue;
    }

    // Verse tokens: line-anchored `\v <label>` plus any inline `\v` tokens
    // after a dropped footnote (the committed snapshots have none): the
    // prefix continues the running verse, each token starts a new block, and
    // the last stays running for later continuation lines.
    final List<RegExpMatch> labelMatches = verseLabelPattern
        .allMatches(trimmed)
        .toList();
    if (labelMatches.isNotEmpty) {
      final RegExpMatch first = labelMatches.first;
      if (first.start > 0 && blockLabel != null) {
        blockLines!.add(trimmed.substring(0, first.start));
      }
      flush();
      for (int i = 0; i < labelMatches.length; i++) {
        if (i > 0) {
          flush();
        }
        final RegExpMatch match = labelMatches[i];
        final int contentEnd = i + 1 < labelMatches.length
            ? labelMatches[i + 1].start
            : trimmed.length;
        startBlock(match.group(1)!, trimmed.substring(match.end, contentEnd));
      }
      continue;
    }

    // Continuation line (poetry, prose, marker-only `\q` lines): belongs to
    // the running verse; text before the first `\v` of the chapter is
    // ignored.
    if (blockLabel != null) {
      blockLines!.add(rawLine);
    }
  }
  flush();

  return List<UsfmChapter>.unmodifiable(chapters);
}

/// Strips one verse block's joined lines to verse text: footnote and
/// cross-reference bodies dropped non-greedy (may span lines), word
/// attributes dropped, remaining backslash tags dropped, whitespace
/// collapsed + trimmed. Returns `''` for note-only blocks (no verse).
///
/// The `\v <label>` header is consumed by the caller, so composite
/// note-only markers (e.g. `\v 15-16`) can never leave residual label digits.
String _verseText(List<String> lines) {
  String text = lines.join('\n');
  text = text
      .replaceAll(RegExp(r'\\f \+[\s\S]*?\\f\*'), '')
      .replaceAll(RegExp(r'\\x \+[\s\S]*?\\x\*'), '')
      .replaceAll(RegExp(r'\|\w+="[^"]*"'), '')
      .replaceAll(RegExp(r'\\[a-z0-9+]+\*?'), '');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.contains('\\')) {
    throw StateError('stripped verse text retains a backslash marker: $text');
  }
  return text;
}
