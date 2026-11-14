// Grounded history authoring orchestrator (Task 3 of the saint-histories
// plan).
//
// For each grounded CE match (Task 2's `data/grounding/manifest.json`):
//   1. deterministic validation of the inputs (grounding text + seed record)
//      BEFORE any model spend;
//   2. one authoring call to `opencode run -m ollama/glm-5.3-flash:cloud`
//      (240 s timeout, 1 retry) with the CE article, the seed record, and a
//      `min(800, 1.5 x anchorWords)` word target (floor 250);
//   3. deterministic validation of the produced text (400-4000 chars, name
//      presence, feast-day consistency, no `{{` placeholders);
//   4. a cross-check call to a model that did NOT write the entry
//      (`ollama/deepseek-v4.1-flash:cloud`, alternating with
//      `ollama/minimax-m3.1-flash:cloud` per batch) returning
//      `{"verdict":"pass"|"issues","issues":[...]}`;
//   5. a dispute loop of at most 2 rounds: issues trigger one repair pass,
//      a second `issues` verdict drops the entry (falls back to the seed
//      bio at render time).
//
// Accepted entries land in `data/histories.json` (slug-keyed; NEVER in the
// byte-pinned `data/saints_source.json`), and every run writes
// `data/histories_run_report.json`. Runs are resumable: slugs already in
// `histories.json` are skipped, so repeated invocations grow the corpus
// idempotently (Task 4 executes those batches).
//
// Model access is subprocess-only (Global Constraints): no API keys, no
// direct endpoints. `opencode run --format json` emits JSONL; the text parts
// are concatenated. The runner is injectable so tests exercise the whole
// orchestration with a fake callable and no network.
//
// Dev-only: tools/ is never imported by runtime code.
//
// Usage (from the package root):
//   dart run tools/histories_orchestrator.dart [--slug <slug>]... \
//       [--limit N] [--concurrency N] [--batch-size N]
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:saint_data/src/utils/history_source.dart';

// ---------------------------------------------------------------------------
// Pinned models / limits
// ---------------------------------------------------------------------------

/// The authoring model (Global Constraints: authors, never cross-checks).
const String defaultAuthorModel = 'ollama/glm-5.3-flash:cloud';

/// Cross-check models, rotated per batch — neither one authored the entry.
const List<String> defaultCrossCheckModels = <String>[
  'ollama/deepseek-v4.1-flash:cloud',
  'ollama/minimax-m3.1-flash:cloud',
];

/// Per-model-call timeout (process killed on expiry).
const Duration defaultCallTimeout = Duration(seconds: 240);

/// Retries after the first failed call (1 retry => at most 2 attempts).
const int defaultCallRetries = 1;

/// Hard bounds on the authored history body (Global Constraints).
const int minHistoryChars = 400;
const int maxHistoryChars = 4000;

/// Word bounds: `min(800, 1.5 x anchor)` with a 250-word floor.
const int minTargetWords = 250;
const int maxTargetWords = 800;

/// Dispute loop cap: first authoring round + at most one repair round.
const int maxRounds = 2;

/// The most grounding text fed to a model prompt. The longest CE article is
/// ~102k chars; clipping keeps prompts inside comfortable context budgets
/// while preserving the opening (early life) and closing (death/veneration)
/// of the article.
///
/// Measured on 2026-11-14: a ~32k-char prompt to
/// `ollama/glm-5.3-flash:cloud` did not finish inside the 240 s call budget,
/// while an ~8k-char prompt returned a complete ~4k-char history in ~49 s.
/// The median CE article is ~3.5k chars, so this clip only touches the long
/// tail (about a tenth of the corpus) and keeps the pipeline inside the
/// plan's per-call timeout.
const int maxGroundingPromptChars = 8000;

/// Opening slice of a clipped article (life, vocation).
const int _groundingHeadChars = 6000;

/// Closing slice of a clipped article (death, veneration, works).
const int _groundingTailChars = 2000;

/// The URL prefix pinned by the `historySource` regex
/// (`^catholic-encyclopedia-1907 https?://www\.newadvent\.org/cathen/\S+$`).
const String _historySourcePrefix = 'catholic-encyclopedia-1907';

/// Regex pinning `historySource` across every contract source class
/// (`catholic-encyclopedia-1907`, `wikipedia`) — see
/// `lib/src/utils/history_source.dart`.
final RegExp historySourcePattern = historySourcePatternFor(
  sourceClasses.keys,
);

// ---------------------------------------------------------------------------
// Exceptions
// ---------------------------------------------------------------------------

/// Raised when a model call, prompt, or reply cannot be used.
class ModelRunnerException implements Exception {
  /// Human-readable failure detail.
  final String message;

  /// Creates an exception with [message].
  const ModelRunnerException(this.message);

  @override
  String toString() => message;
}

/// Fatal tool error surfaced with exit code 1.
class OrchestratorException implements Exception {
  /// Human-readable failure detail.
  final String message;

  /// Creates an exception with [message].
  const OrchestratorException(this.message);

  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// Inputs
// ---------------------------------------------------------------------------

/// The seed facts a history must stay consistent with
/// (`data/saints_source.json`).
class SaintSeed {
  /// Slug-keyed identity used everywhere downstream.
  final String slug;

  /// Display name, e.g. `St. Francis of Assisi`.
  final String name;

  /// Feast day as `MM-DD`.
  final String feastDay;

  /// Canonization year, when the seed records one.
  final String canonized;

  /// The existing short story; the history extends it, never replaces it.
  final String bio;

  /// Patronage needs (`animals`, `ecology`, ...), when recorded.
  final List<String> patronages;

  /// Creates a seed record.
  const SaintSeed({
    required this.slug,
    required this.name,
    required this.feastDay,
    required this.canonized,
    required this.bio,
    required this.patronages,
  });
}

/// One grounded CE article (Task 2 output).
class GroundingText {
  /// Slug this article anchors.
  final String slug;

  /// CE article code, e.g. `06221a`.
  final String ceCode;

  /// Canonical New Advent article URL.
  final String url;

  /// Clean article text (paragraphs separated by blank lines).
  final String text;

  /// Creates a grounding record.
  const GroundingText({
    required this.slug,
    required this.ceCode,
    required this.url,
    required this.text,
  });
}

/// One saint to author this run.
class AuthoringJob {
  /// Seed facts for the saint.
  final SaintSeed seed;

  /// The grounding article the history must be based on.
  final GroundingText grounding;

  /// Creates a job.
  const AuthoringJob({required this.seed, required this.grounding});
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

/// Final status of one authoring job.
enum EntryStatus {
  /// Accepted by the deterministic validator and the cross-checker.
  accepted,

  /// Dropped after the dispute loop cap (falls back to the seed bio).
  dropped,

  /// Already present in `histories.json` from a previous run.
  skipped,

  /// A model call failed; retryable on the next run.
  error,
}

/// A `data/histories.json` entry (shape pinned by the plan).
class HistoryEntry {
  /// Slug key (also repeated inside the value).
  final String slug;

  /// The authored history body.
  final String history;

  /// Pinned provenance: `catholic-encyclopedia-1907 <url>`.
  final String historySource;

  /// Source article code.
  final String ceCode;

  /// ISO-8601 UTC authoring timestamp.
  final String authoredAt;

  /// The cross-check model that accepted this entry.
  final String checkedBy;

  /// Authoring rounds consumed (1 = accepted first pass).
  final int roundsUsed;

  /// Creates an entry.
  const HistoryEntry({
    required this.slug,
    required this.history,
    required this.historySource,
    required this.ceCode,
    required this.authoredAt,
    required this.checkedBy,
    required this.roundsUsed,
  });

  /// Serializes the pinned key set, in the plan's order.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'slug': slug,
      'history': history,
      'historySource': historySource,
      'ceCode': ceCode,
      'authoredAt': authoredAt,
      'checkedBy': checkedBy,
      'roundsUsed': roundsUsed,
    };
  }
}

/// Outcome of one authoring job (also a run-report row source).
class EntryOutcome {
  /// Slug of the saint.
  final String slug;

  /// CE article code, when known.
  final String ceCode;

  /// Final status.
  final EntryStatus status;

  /// The accepted entry, when [status] is [EntryStatus.accepted].
  final HistoryEntry? entry;

  /// Deterministic issues and/or cross-checker issues that survived.
  final List<String> issues;

  /// Authoring rounds consumed (0 for skipped/error).
  final int roundsUsed;

  /// Cross-check model responsible for this entry.
  final String? checkedBy;

  /// Transient-failure detail (error status only).
  final String? reason;

  /// Creates an outcome.
  const EntryOutcome({
    required this.slug,
    required this.ceCode,
    required this.status,
    this.entry,
    this.issues = const <String>[],
    this.roundsUsed = 0,
    this.checkedBy,
    this.reason,
  });
}

/// The cross-checker's parsed verdict.
class CrossCheckVerdict {
  /// True when the checker found no unsupported claims.
  final bool pass;

  /// Concrete issues to feed into the repair round.
  final List<String> issues;

  /// Creates a verdict.
  const CrossCheckVerdict({required this.pass, required this.issues});
}

// ---------------------------------------------------------------------------
// Text helpers
// ---------------------------------------------------------------------------

final RegExp _ansiPattern = RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]');

/// Removes ANSI escape sequences (opencode's plain output is styled).
String stripAnsi(String input) => input.replaceAll(_ansiPattern, '');

/// Words in [text] (whitespace-separated tokens).
int wordCount(String text) {
  return text
      .trim()
      .split(RegExp(r'\s+'))
      .where((String token) => token.isNotEmpty)
      .length;
}

/// `min(800, 1.5 x anchorWords)` with the 250-word floor.
int targetWordCount({required int anchorWords}) {
  final int scaled = (anchorWords * 1.5).round();
  if (scaled < minTargetWords) {
    return minTargetWords;
  }
  if (scaled > maxTargetWords) {
    return maxTargetWords;
  }
  return scaled;
}

/// Clips long article text to [maxGroundingPromptChars], keeping the opening
/// (origins) and the closing (death, veneration) of the article.
String clipGrounding(String text) {
  if (text.length <= maxGroundingPromptChars) {
    return text;
  }
  final String head = text.substring(0, _groundingHeadChars).trimRight();
  final String tail = text
      .substring(text.length - _groundingTailChars)
      .trimLeft();
  return '$head\n\n[article middle omitted for length]\n\n$tail';
}

/// A short single-line preview for logs and error messages.
String _preview(String text, {int maxChars = 200}) {
  final String oneLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return oneLine.length <= maxChars
      ? oneLine
      : '${oneLine.substring(0, maxChars)}…';
}

/// The pinned provenance string for a CE article code.
String historySourceFor(String ceCode) {
  return '$_historySourcePrefix https://www.newadvent.org/cathen/$ceCode.htm';
}

/// The class-aware provenance string for a grounding record: CE keeps the
/// article-code URL shape, wikipedia carries the manifest's article URL.
String historySourceForClass(String sourceClass, GroundingText grounding) {
  if (!sourceClasses.containsKey(sourceClass)) {
    throw ArgumentError.value(
      sourceClass,
      'sourceClass',
      'unknown source class; expected one of ${sourceClasses.keys.toList()}',
    );
  }
  if (sourceClass == _historySourcePrefix) {
    return historySourceFor(grounding.ceCode);
  }
  if (grounding.url.isEmpty) {
    throw OrchestratorException(
      'wikipedia grounding for ${grounding.slug} has no manifest URL; '
      'its historySource cannot be built',
    );
  }
  return '$sourceClass ${grounding.url}';
}

// ---------------------------------------------------------------------------
// Deterministic validation (no model spend)
// ---------------------------------------------------------------------------

/// Name particles/honorifics that cannot identify a saint on their own.
const Set<String> _nameStopwords = <String>{
  'st',
  'saint',
  'ste',
  'blessed',
  'bl',
  'venerable',
  'pope',
  'martyr',
  'apostle',
  'of',
  'the',
  'de',
  'da',
  'di',
  'del',
  'della',
  'la',
  'le',
  'du',
  'von',
  'van',
  'and',
  'ii',
  'iii',
  'iv',
  'v',
  'vi',
  'vii',
  'viii',
  'ix',
  'x',
  'xi',
  'xii',
};

/// Folds the Latin-1 accents common in saint names so "Therese" matches
/// "Thérèse" and "Benedicte" matches "Bénédicte".
const Map<String, String> _diacriticFold = <String, String>{
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'å': 'a',
  'ā': 'a',
  'æ': 'ae',
  'ç': 'c',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'ē': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ī': 'i',
  'ñ': 'n',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ø': 'o',
  'ō': 'o',
  'œ': 'oe',
  'ß': 'ss',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ū': 'u',
  'ý': 'y',
  'ÿ': 'y',
};

String _foldAccents(String input) {
  final StringBuffer buffer = StringBuffer();
  for (final String char in input.split('')) {
    buffer.write(_diacriticFold[char] ?? char);
  }
  return buffer.toString();
}

/// The distinctive token identifying the saint (`Francis` for
/// `St. Francis of Assisi`), or null when the name has none.
String? primaryNameToken(String name) {
  final List<String> tokens = _foldAccents(name.toLowerCase())
      .split(RegExp(r'[^\p{L}]+', unicode: true))
      .where((String token) => token.length > 1)
      .toList();
  for (final String token in tokens) {
    if (!_nameStopwords.contains(token)) {
      return token;
    }
  }
  return null;
}

const List<String> _monthNames = <String>[
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
];

const List<String> _monthAbbreviations = <String>[
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'sept',
  'oct',
  'nov',
  'dec',
];

final RegExp _monthFirstDate = RegExp(
  '\\b(${<String>[..._monthNames, ..._monthAbbreviations].join('|')})'
  r'\.?\s+(\d{1,2})\b',
  caseSensitive: false,
);

final RegExp _dayFirstDate = RegExp(
  r'\b(\d{1,2})\s+('
  '${<String>[..._monthNames, ..._monthAbbreviations].join('|')}'
  r')\b',
  caseSensitive: false,
);

final RegExp _numericDate = RegExp(r'\b(\d{1,2})[-/](\d{1,2})\b');
final RegExp _feastPattern = RegExp(r'\bfeast\b', caseSensitive: false);

int _monthIndex(String raw) {
  final String token = raw.toLowerCase().replaceAll('.', '');
  final int full = _monthNames.indexOf(token);
  if (full >= 0) {
    return full + 1;
  }
  final int abbreviated = _monthAbbreviations.indexOf(token);
  return abbreviated >= 0 ? abbreviated + 1 : -1;
}

/// A `(month, day)` date parsed from [raw], or null.
({int month, int day})? _parseSeedDate(String raw) {
  final RegExpMatch? match = RegExp(r'^(\d{1,2})-(\d{1,2})$').firstMatch(raw);
  if (match == null) {
    return null;
  }
  final int month = int.tryParse(match.group(1)!) ?? 0;
  final int day = int.tryParse(match.group(2)!) ?? 0;
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  return (month: month, day: day);
}

/// The first calendar date found in [window], or null.
({int month, int day})? _firstDateIn(String window) {
  final RegExpMatch? monthFirst = _monthFirstDate.firstMatch(window);
  final RegExpMatch? dayFirst = _dayFirstDate.firstMatch(window);
  final RegExpMatch? numeric = _numericDate.firstMatch(window);

  // Choose the earliest occurrence among the forms that matched.
  final List<({int month, int day, int index})> candidates =
      <({int month, int day, int index})>[];
  if (monthFirst != null) {
    final int month = _monthIndex(monthFirst.group(1)!);
    final int day = int.tryParse(monthFirst.group(2)!) ?? 0;
    if (month > 0) {
      candidates.add((month: month, day: day, index: monthFirst.start));
    }
  }
  if (dayFirst != null) {
    final int month = _monthIndex(dayFirst.group(2)!);
    final int day = int.tryParse(dayFirst.group(1)!) ?? 0;
    if (month > 0) {
      candidates.add((month: month, day: day, index: dayFirst.start));
    }
  }
  if (numeric != null) {
    final int month = int.tryParse(numeric.group(1)!) ?? 0;
    final int day = int.tryParse(numeric.group(2)!) ?? 0;
    if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      candidates.add((month: month, day: day, index: numeric.start));
    }
  }
  if (candidates.isEmpty) {
    return null;
  }
  candidates.sort(
    (
      ({int month, int day, int index}) a,
      ({int month, int day, int index}) b,
    ) => a.index.compareTo(b.index),
  );
  return (month: candidates.first.month, day: candidates.first.day);
}

/// A feast-day consistency issue, or null when the text is consistent (or
/// says nothing about the feast day).
///
/// Only dates asserted *near* the word "feast" are compared: a history may
/// legitimately mention the death date (3 October) alongside the feast
/// (4 October), so the death date must not be treated as a contradiction.
String? _feastDayIssue(String history, String feastDay) {
  final ({int month, int day})? seedDate = _parseSeedDate(feastDay);
  if (seedDate == null) {
    return null;
  }
  for (final RegExpMatch match in _feastPattern.allMatches(history)) {
    final int start = match.start - 80 < 0 ? 0 : match.start - 80;
    final int end = match.end + 140 > history.length
        ? history.length
        : match.end + 140;
    final ({int month, int day})? stated = _firstDateIn(
      history.substring(start, end),
    );
    if (stated == null) {
      continue;
    }
    if (stated.month != seedDate.month || stated.day != seedDate.day) {
      return 'history states a feast day of '
          '${stated.day}/${stated.month} but the seed record pins '
          '$feastDay (MM-DD)';
    }
  }
  return null;
}

/// Deterministic checks that must pass BEFORE any model spend and again on
/// every drafted history. Returns an empty list when the text is acceptable.
List<String> validateDraft({required String history, required SaintSeed seed}) {
  final List<String> issues = <String>[];
  final String trimmed = history.trim();
  final int length = trimmed.length;
  if (length < minHistoryChars) {
    issues.add(
      'history is $length characters; the minimum is $minHistoryChars',
    );
  }
  if (length > maxHistoryChars) {
    issues.add(
      'history is $length characters; the maximum is $maxHistoryChars',
    );
  }
  if (trimmed.contains('{{')) {
    issues.add('history contains an unfilled template placeholder ("{{")');
  }
  final String? token = primaryNameToken(seed.name);
  if (token != null && !_foldAccents(trimmed.toLowerCase()).contains(token)) {
    issues.add('history does not name the saint (expected "${seed.name}")');
  }
  final String? feastIssue = _feastDayIssue(trimmed, seed.feastDay);
  if (feastIssue != null) {
    issues.add(feastIssue);
  }
  return issues;
}

// ---------------------------------------------------------------------------
// Prompts
// ---------------------------------------------------------------------------

String _seedBlock(SaintSeed seed) {
  final StringBuffer buffer = StringBuffer()
    ..writeln('name: ${seed.name}')
    ..writeln('feastDay: ${seed.feastDay} (MM-DD)');
  if (seed.canonized.isNotEmpty) {
    buffer.writeln('canonized: ${seed.canonized}');
  }
  if (seed.patronages.isNotEmpty) {
    buffer.writeln('patronages: ${seed.patronages.join(', ')}');
  }
  buffer.writeln('existingShortBio: ${seed.bio}');
  return buffer.toString().trimRight();
}

const String _styleRules = '''
- Ground every claim in the ARTICLE TEXT and the SAINT RECORD below.
- Never invent miracles, dates, names, or quotations. Where a detail rests on
  later legend rather than the article, hedge with "tradition holds".
- Stay consistent with the SAINT RECORD (feast day, canonization, patronages).
- Reverent, neutral, encyclopedic tone: no marketing language, no prayers,
  no second-person address, no headings, no markdown, no citation markers.
- Plain prose paragraphs separated by blank lines.''';

/// The first-pass authoring prompt: grounding text + seed facts + target.
String buildAuthorPrompt({
  required SaintSeed seed,
  required GroundingText grounding,
}) {
  final int target = targetWordCount(anchorWords: wordCount(grounding.text));
  return '''
You are a Catholic hagiography editor writing a grounded summary history of a
saint for a mobile app.

$_styleRules
- Target length: about $target words, but the hard bound is
  $minHistoryChars-$maxHistoryChars characters (roughly 650 words); when the
  two conflict, the character bound wins.

SAINT RECORD:
${_seedBlock(seed)}

ARTICLE TEXT (Catholic Encyclopedia, 1907-12):
${clipGrounding(grounding.text)}

Return ONLY a JSON object with this exact shape, no prose and no code fences:
{"history": "<the history text, paragraphs separated by blank lines>"}
''';
}

/// The repair prompt after a deterministic or cross-check failure.
String buildRepairPrompt({
  required SaintSeed seed,
  required GroundingText grounding,
  required String previousHistory,
  required List<String> issues,
}) {
  final int target = targetWordCount(anchorWords: wordCount(grounding.text));
  final String issueList = issues.map((String issue) => '- $issue').join('\n');
  return '''
You are a Catholic hagiography editor repairing a draft history of a saint.

$_styleRules
- Target length: about $target words, but the hard bound is
  $minHistoryChars-$maxHistoryChars characters (roughly 650 words); when the
  two conflict, the character bound wins.
- Fix every issue listed below. Remove any claim you cannot support from the
  ARTICLE TEXT or the SAINT RECORD.

ISSUES TO FIX:
$issueList

SAINT RECORD:
${_seedBlock(seed)}

ARTICLE TEXT (Catholic Encyclopedia, 1907-12):
${clipGrounding(grounding.text)}

PREVIOUS DRAFT:
$previousHistory

Return ONLY a JSON object with this exact shape, no prose and no code fences:
{"history": "<the corrected history text>"}
''';
}

/// The cross-check prompt: a different model re-reads the draft against the
/// same grounding text and returns a JSON verdict.
String buildCrossCheckPrompt({
  required SaintSeed seed,
  required GroundingText grounding,
  required String history,
}) {
  return '''
You are a careful fact-checker. Decide whether the HISTORY below is fully
supported by the ARTICLE TEXT (a 1907-12 Catholic Encyclopedia article) and
consistent with the SAINT RECORD.

Flag as issues:
- specific claims, dates, names, miracles, or quotations not supported by the
  ARTICLE TEXT;
- contradictions with the SAINT RECORD (feast day, canonization, patronages);
- confabulated detail presented as fact rather than as tradition;
- promotional or devotional excess unbecoming of an encyclopedia summary;
- a text that is not actually about this saint.

Do not flag stylistic preferences or details the article states plainly.

SAINT RECORD:
${_seedBlock(seed)}

ARTICLE TEXT (Catholic Encyclopedia, 1907-12):
${clipGrounding(grounding.text)}

HISTORY:
$history

Return ONLY a JSON object with this exact shape, no prose and no code fences:
{"verdict": "pass", "issues": []}
or
{"verdict": "issues", "issues": ["<specific, actionable issue>", ...]}
''';
}

// ---------------------------------------------------------------------------
// Model reply parsing
// ---------------------------------------------------------------------------

/// Extracts the first decodable JSON object from a model reply, tolerating
/// code fences, prose before/after, and nested braces.
Map<String, dynamic> parseModelEnvelope(String raw) {
  final String text = stripAnsi(raw);
  int start = text.indexOf('{');
  while (start != -1) {
    int end = text.lastIndexOf('}');
    while (end > start) {
      final String candidate = text.substring(start, end + 1);
      try {
        final Object? decoded = jsonDecode(candidate);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } on FormatException {
        // Try a shorter span ending at the previous '}'.
      }
      end = text.lastIndexOf('}', end - 1);
    }
    start = text.indexOf('{', start + 1);
  }
  throw ModelRunnerException(
    'model reply contained no JSON object: ${_preview(text)}',
  );
}

/// The history body from an authoring reply. Accepts `{"history": "..."}`
/// (the pinned envelope), a bare JSON string, or plain prose.
String extractHistoryFromReply(String raw) {
  Map<String, dynamic>? envelope;
  try {
    envelope = parseModelEnvelope(raw);
  } on ModelRunnerException {
    envelope = null;
  }
  if (envelope != null) {
    for (final String key in <String>['history', 'text', 'content']) {
      final Object? value = envelope[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    throw ModelRunnerException(
      'author reply JSON has no "history" string: ${_preview(raw)}',
    );
  }
  final String plain = stripAnsi(raw).trim();
  if (plain.isEmpty) {
    throw const ModelRunnerException('author reply was empty');
  }
  return plain;
}

/// Joins the text parts of `opencode run --format json` (JSONL) output.
String extractTextFromJsonLines(String raw) {
  final StringBuffer buffer = StringBuffer();
  for (final String line in raw.split('\n')) {
    final String trimmed = line.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    try {
      final Object? decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic> && decoded['type'] == 'text') {
        final Object? part = decoded['part'];
        if (part is Map && part['text'] is String) {
          buffer.write(part['text'] as String);
        }
      }
    } on FormatException {
      // Not a JSONL row; the plain-output fallback handles it.
    }
  }
  return buffer.toString();
}

/// Plain-output fallback: strips ANSI styling and opencode's banner lines.
String cleanPlainOutput(String raw) {
  final List<String> kept = <String>[];
  for (final String line in stripAnsi(raw).split('\n')) {
    final String trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('> build ·')) {
      continue;
    }
    kept.add(line);
  }
  return kept.join('\n').trim();
}

/// The cross-checker's verdict from its reply.
CrossCheckVerdict parseVerdict(String raw) {
  final Map<String, dynamic> envelope = parseModelEnvelope(raw);
  final String verdict = (envelope['verdict'] ?? envelope['result'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  final Object? rawIssues = envelope['issues'] ?? envelope['problems'];
  final List<String> issues = <String>[];
  if (rawIssues is List) {
    for (final Object? issue in rawIssues) {
      final String text = issue.toString().trim();
      if (text.isNotEmpty) {
        issues.add(text);
      }
    }
  } else if (rawIssues is String && rawIssues.trim().isNotEmpty) {
    issues.add(rawIssues.trim());
  }
  final bool pass =
      verdict == 'pass' ||
      verdict == 'passed' ||
      verdict == 'ok' ||
      verdict == 'approve' ||
      verdict == 'approved';
  if (pass) {
    return const CrossCheckVerdict(pass: true, issues: <String>[]);
  }
  if (issues.isEmpty) {
    issues.add(
      'cross-check returned verdict "${verdict.isEmpty ? '(none)' : verdict}" '
      'with no issues listed',
    );
  }
  return CrossCheckVerdict(pass: false, issues: issues);
}

// ---------------------------------------------------------------------------
// Real model runner (`opencode run` subprocess)
// ---------------------------------------------------------------------------

/// Injected model callable: returns the model's text for a prompt.
typedef ModelRunner =
    Future<String> Function({required String model, required String prompt});

/// A [ModelRunner] backed by `opencode run -m <model>` (no API keys).
ModelRunner opencodeModelRunner({
  Duration timeout = defaultCallTimeout,
  int retries = defaultCallRetries,
  String? workingDirectory,
}) {
  final String directory = workingDirectory ?? Directory.systemTemp.path;
  return ({required String model, required String prompt}) async {
    Object? lastError;
    for (int attempt = 0; attempt <= retries; attempt++) {
      try {
        return await _runOpencodeOnce(
          model: model,
          prompt: prompt,
          timeout: timeout,
          workingDirectory: directory,
        );
      } catch (error) {
        lastError = error;
      }
    }
    throw ModelRunnerException(
      'opencode run -m $model failed after ${retries + 1} attempt(s): '
      '$lastError',
    );
  };
}

Future<String> _runOpencodeOnce({
  required String model,
  required String prompt,
  required Duration timeout,
  required String workingDirectory,
}) async {
  final Process process = await Process.start('opencode', <String>[
    'run',
    '-m',
    model,
    '--archived',
    '--format',
    'json',
    prompt,
  ], workingDirectory: workingDirectory);
  final StringBuffer stdoutBuffer = StringBuffer();
  final StringBuffer stderrBuffer = StringBuffer();
  // `opencode run` waits on stdin when it is an open pipe (it supports piped
  // prompts); close it immediately so the call starts without a TTY.
  try {
    await process.stdin.close();
  } on IOException {
    // The child already exited; the exit code below reports why.
  }
  final StreamSubscription<String> stdoutSub = process.stdout
      .transform(utf8.decoder)
      .listen(stdoutBuffer.write);
  final StreamSubscription<String> stderrSub = process.stderr
      .transform(utf8.decoder)
      .listen(stderrBuffer.write);

  final int exitCode;
  try {
    exitCode = await process.exitCode.timeout(timeout);
  } on TimeoutException {
    process.kill(ProcessSignal.sigkill);
    await stdoutSub.cancel();
    await stderrSub.cancel();
    throw ModelRunnerException(
      'opencode run -m $model timed out after ${timeout.inSeconds}s',
    );
  }
  await stdoutSub.cancel();
  await stderrSub.cancel();

  final String raw = stdoutBuffer.toString();
  if (exitCode != 0) {
    throw ModelRunnerException(
      'opencode run -m $model exited $exitCode: '
      '${_preview(stderrBuffer.toString().isEmpty ? raw : stderrBuffer.toString())}',
    );
  }
  final String text = extractTextFromJsonLines(raw).trim();
  final String result = text.isEmpty ? cleanPlainOutput(raw) : text;
  if (result.trim().isEmpty) {
    throw ModelRunnerException('opencode run -m $model produced no text');
  }
  return result;
}

// ---------------------------------------------------------------------------
// Orchestrator
// ---------------------------------------------------------------------------

/// Runs authoring + cross-check jobs with a small process pool.
class HistoryOrchestrator {
  /// The injected model callable (real subprocess in production, fake in
  /// tests).
  final ModelRunner runModel;

  /// The authoring model (must differ from every cross-check model).
  final String authorModel;

  /// Cross-check models, rotated per batch of [crossCheckBatchSize] entries.
  final List<String> crossCheckModels;

  /// Number of entries processed concurrently.
  final int concurrency;

  /// Entries per cross-check-model batch (alternation granularity).
  final int crossCheckBatchSize;

  /// UTC clock used for `authoredAt` (injectable for deterministic tests).
  final DateTime Function() clock;

  /// Per-entry logging sink.
  final void Function(String message) log;

  /// Creates an orchestrator.
  HistoryOrchestrator({
    required this.runModel,
    this.authorModel = defaultAuthorModel,
    this.crossCheckModels = defaultCrossCheckModels,
    this.concurrency = 4,
    this.crossCheckBatchSize = 10,
    DateTime Function()? clock,
    this.log = _stdoutLog,
  }) : clock = clock ?? DateTime.now {
    if (crossCheckModels.isEmpty) {
      throw ArgumentError.value(
        crossCheckModels,
        'crossCheckModels',
        'at least one cross-check model is required',
      );
    }
    if (crossCheckModels.contains(authorModel)) {
      throw ArgumentError(
        'the cross-check model must not be the authoring model '
        '($authorModel)',
      );
    }
  }

  /// Runs every job (up to [concurrency] at a time) and returns outcomes in
  /// job order. Slugs in [existingSlugs] are skipped without a model call.
  Future<List<EntryOutcome>> runJobs(
    List<AuthoringJob> jobs, {
    Set<String> existingSlugs = const <String>{},
    String sourceClass = 'catholic-encyclopedia-1907',
  }) async {
    if (!sourceClasses.containsKey(sourceClass)) {
      throw ArgumentError.value(
        sourceClass,
        'sourceClass',
        'unknown source class; expected one of ${sourceClasses.keys.toList()}',
      );
    }
    final List<EntryOutcome?> results = List<EntryOutcome?>.filled(
      jobs.length,
      null,
    );
    int nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final int index = nextIndex;
        if (index >= jobs.length) {
          return;
        }
        nextIndex = index + 1;
        final AuthoringJob job = jobs[index];
        final String slug = job.seed.slug;
        if (existingSlugs.contains(slug)) {
          results[index] = EntryOutcome(
            slug: slug,
            ceCode: job.grounding.ceCode,
            status: EntryStatus.skipped,
          );
          log('[$slug] skipped (already authored)');
          continue;
        }
        results[index] = await _authorOne(index, job, sourceClass: sourceClass);
      }
    }

    final int workers = concurrency < 1
        ? 1
        : (concurrency > jobs.length ? jobs.length : concurrency);
    if (workers == 0) {
      return <EntryOutcome>[];
    }
    await Future.wait(<Future<void>>[
      for (int i = 0; i < workers; i++) worker(),
    ]);
    return results.cast<EntryOutcome>();
  }

  /// The cross-check model for job [index]: batches alternate models, and no
  /// entry is ever checked by the model that wrote it.
  String crossCheckModelFor(int index) {
    final int batch =
        index ~/ (crossCheckBatchSize < 1 ? 1 : crossCheckBatchSize);
    return crossCheckModels[batch % crossCheckModels.length];
  }

  Future<EntryOutcome> _authorOne(
    int index,
    AuthoringJob job, {
    String sourceClass = 'catholic-encyclopedia-1907',
  }) async {
    final String slug = job.seed.slug;
    final String ceCode = job.grounding.ceCode;
    final String checker = crossCheckModelFor(index);

    EntryOutcome error(String message) {
      log('[$slug] error: $message');
      return EntryOutcome(
        slug: slug,
        ceCode: ceCode,
        status: EntryStatus.error,
        reason: message,
        checkedBy: checker,
      );
    }

    // Pre-flight: never spend a token on an unusable job.
    if (job.grounding.text.trim().isEmpty) {
      return error('grounding text is empty');
    }
    final String? token = primaryNameToken(job.seed.name);
    if (token == null) {
      return error('seed name "${job.seed.name}" has no identifying token');
    }

    List<String> pendingIssues = const <String>[];
    String? draft;

    for (int round = 1; round <= maxRounds; round++) {
      final String prompt = draft == null
          ? buildAuthorPrompt(seed: job.seed, grounding: job.grounding)
          : buildRepairPrompt(
              seed: job.seed,
              grounding: job.grounding,
              previousHistory: draft,
              issues: pendingIssues,
            );

      final String reply;
      try {
        log('[$slug] round $round: authoring (${job.seed.name})');
        reply = await runModel(model: authorModel, prompt: prompt);
      } on ModelRunnerException catch (modelError) {
        return error('authoring call failed: ${modelError.message}');
      } catch (modelError) {
        return error('authoring call failed: $modelError');
      }

      final String candidate;
      try {
        candidate = extractHistoryFromReply(reply);
      } on ModelRunnerException catch (replyError) {
        // Retryable model misbehavior, not a transient transport error.
        pendingIssues = <String>[replyError.message];
        draft = null;
        log('[$slug] round $round: unusable reply (${replyError.message})');
        continue;
      }

      final List<String> deterministic = validateDraft(
        history: candidate,
        seed: job.seed,
      );
      if (deterministic.isNotEmpty) {
        pendingIssues = deterministic;
        draft = candidate;
        log(
          '[$slug] round $round: validator rejected '
          '(${deterministic.join('; ')})',
        );
        continue;
      }

      final String verdictReply;
      try {
        log('[$slug] round $round: cross-check ($checker)');
        verdictReply = await runModel(
          model: checker,
          prompt: buildCrossCheckPrompt(
            seed: job.seed,
            grounding: job.grounding,
            history: candidate,
          ),
        );
      } on ModelRunnerException catch (modelError) {
        return error('cross-check call failed: ${modelError.message}');
      } catch (modelError) {
        return error('cross-check call failed: $modelError');
      }

      CrossCheckVerdict verdict;
      try {
        verdict = parseVerdict(verdictReply);
      } on ModelRunnerException {
        verdict = const CrossCheckVerdict(
          pass: false,
          issues: <String>[
            'cross-check reply was not parseable JSON; treat the draft as '
                'unverified',
          ],
        );
      }

      if (verdict.pass) {
        final String authoredAt = clock().toUtc().toIso8601String();
        final HistoryEntry entry = HistoryEntry(
          slug: slug,
          history: candidate,
          historySource: historySourceForClass(sourceClass, job.grounding),
          ceCode: ceCode,
          authoredAt: authoredAt,
          checkedBy: checker,
          roundsUsed: round,
        );
        log(
          '[$slug] accepted in $round round(s), '
          '${candidate.length} chars, checked by $checker',
        );
        return EntryOutcome(
          slug: slug,
          ceCode: ceCode,
          status: EntryStatus.accepted,
          entry: entry,
          roundsUsed: round,
          checkedBy: checker,
        );
      }

      pendingIssues = verdict.issues;
      draft = candidate;
      log(
        '[$slug] round $round: cross-check issues (${verdict.issues.join('; ')})',
      );
    }

    log(
      '[$slug] dropped after $maxRounds rounds (${pendingIssues.join('; ')})',
    );
    return EntryOutcome(
      slug: slug,
      ceCode: ceCode,
      status: EntryStatus.dropped,
      issues: pendingIssues,
      roundsUsed: maxRounds,
      checkedBy: checker,
    );
  }
}

void _stdoutLog(String message) {
  stdout.writeln(message);
}

// ---------------------------------------------------------------------------
// Run report (pinned shape)
// ---------------------------------------------------------------------------

/// Builds `data/histories_run_report.json`.
Map<String, dynamic> buildRunReport({
  required List<EntryOutcome> outcomes,
  required String authorModel,
  required List<String> crossCheckModels,
  required DateTime generatedAt,
}) {
  int count(EntryStatus status) {
    return outcomes.where((EntryOutcome o) => o.status == status).length;
  }

  return <String, dynamic>{
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'authorModel': authorModel,
    'crossCheckModels': crossCheckModels,
    'counts': <String, dynamic>{
      'selected': outcomes.length,
      'accepted': count(EntryStatus.accepted),
      'dropped': count(EntryStatus.dropped),
      'skipped': count(EntryStatus.skipped),
      'error': count(EntryStatus.error),
    },
    'entries': <Map<String, dynamic>>[
      for (final EntryOutcome outcome in outcomes)
        <String, dynamic>{
          'slug': outcome.slug,
          'ceCode': outcome.ceCode,
          'status': outcome.status.name,
          'roundsUsed': outcome.roundsUsed,
          'checkedBy': outcome.checkedBy,
          'chars': outcome.entry?.history.length,
          'issues': outcome.issues,
          if (outcome.reason != null) 'reason': outcome.reason,
        },
    ],
  };
}

// ---------------------------------------------------------------------------
// File pipeline (reads grounding + seeds, writes histories.json + report)
// ---------------------------------------------------------------------------

/// Pretty JSON encoder used for every output file.
const JsonEncoder _prettyEncoder = JsonEncoder.withIndent('  ');

/// The outcome of one file-backed run.
class OrchestratorRun {
  /// Per-job outcomes, in selection order.
  final List<EntryOutcome> outcomes;

  /// Where the corpus lives (`data/histories.json`).
  final String historiesPath;

  /// Where the per-run report lives (`data/histories_run_report.json`).
  final String reportPath;

  /// Entries in the corpus after this run.
  final int corpusSize;

  /// Creates a run summary.
  const OrchestratorRun({
    required this.outcomes,
    required this.historiesPath,
    required this.reportPath,
    required this.corpusSize,
  });
}

/// Reads the seed record for [slug] from `data/saints_source.json`.
Map<String, SaintSeed> loadSeeds(String saintsSourcePath) {
  final Map<String, dynamic> decoded =
      jsonDecode(File(saintsSourcePath).readAsStringSync())
          as Map<String, dynamic>;
  final List<dynamic> saints = decoded['saints'] as List<dynamic>;
  final Map<String, SaintSeed> seeds = <String, SaintSeed>{};
  for (final Object? row in saints) {
    if (row is! Map<String, dynamic>) {
      continue;
    }
    final String slug = (row['slug'] ?? '').toString();
    if (slug.isEmpty) {
      continue;
    }
    seeds[slug] = SaintSeed(
      slug: slug,
      name: (row['name'] ?? '').toString(),
      feastDay: (row['feastDay'] ?? '').toString(),
      canonized: (row['canonized'] ?? '').toString(),
      bio: (row['bio'] ?? '').toString(),
      patronages: <String>[
        for (final Object? patronage
            in (row['patronages'] as List<dynamic>?) ?? const <dynamic>[])
          if (patronage is Map<String, dynamic>)
            (patronage['need'] ?? '').toString()
          else
            patronage.toString(),
      ].where((String need) => need.isNotEmpty).toList(),
    );
  }
  return seeds;
}

/// Builds the authoring jobs from the grounding manifest, in manifest order.
List<AuthoringJob> loadGroundingJobs({
  required String groundingDir,
  required Map<String, SaintSeed> seeds,
  List<String> onlySlugs = const <String>[],
  int? limit,
}) {
  final File manifestFile = File('$groundingDir/manifest.json');
  if (!manifestFile.existsSync()) {
    throw OrchestratorException(
      'missing ${manifestFile.path} — run tools/scrape_grounding.dart first',
    );
  }
  final Map<String, dynamic> manifest =
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
  final List<dynamic> articles = manifest['articles'] as List<dynamic>;
  final Set<String> filters = onlySlugs.toSet();
  final List<AuthoringJob> jobs = <AuthoringJob>[];
  for (final Object? row in articles) {
    if (row is! Map<String, dynamic>) {
      continue;
    }
    final String slug = (row['slug'] ?? '').toString();
    if (slug.isEmpty || (filters.isNotEmpty && !filters.contains(slug))) {
      continue;
    }
    final SaintSeed? seed = seeds[slug];
    if (seed == null) {
      throw OrchestratorException(
        'grounded slug "$slug" has no seed record in saints_source.json',
      );
    }
    final String file = (row['file'] ?? '').toString();
    final String path = '$groundingDir/$file';
    final File groundingFile = File(path);
    if (!groundingFile.existsSync()) {
      throw OrchestratorException('missing grounding file $path');
    }
    jobs.add(
      AuthoringJob(
        seed: seed,
        grounding: GroundingText(
          slug: slug,
          ceCode: (row['ceCode'] ?? '').toString(),
          url: (row['url'] ?? '').toString(),
          text: groundingFile.readAsStringSync(),
        ),
      ),
    );
    if (limit != null && jobs.length >= limit) {
      break;
    }
  }
  return jobs;
}

/// Reads the existing corpus (slug-keyed), or an empty map when absent.
Map<String, dynamic> readHistories(String path) {
  final File file = File(path);
  if (!file.existsSync()) {
    return <String, dynamic>{};
  }
  final Object? decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw OrchestratorException('$path is not a JSON object');
  }
  return decoded;
}

/// Runs the full pipeline: load, author, merge, report.
Future<OrchestratorRun> run({
  String packageRoot = '.',
  List<String> onlySlugs = const <String>[],
  int? limit,
  int concurrency = 4,
  int crossCheckBatchSize = 10,
  String authorModel = defaultAuthorModel,
  List<String> crossCheckModels = defaultCrossCheckModels,
  ModelRunner? runModel,
  void Function(String message) log = _stdoutLog,
  String sourceClass = 'catholic-encyclopedia-1907',
}) async {
  if (!sourceClasses.containsKey(sourceClass)) {
    throw ArgumentError.value(
      sourceClass,
      'sourceClass',
      'unknown source class; expected one of ${sourceClasses.keys.toList()}',
    );
  }
  final String groundingDir =
      '$packageRoot/${groundingDirFor(sourceClass)}';
  final String seedsPath = '$packageRoot/data/saints_source.json';
  final String historiesPath = '$packageRoot/data/histories.json';
  final String reportPath = '$packageRoot/data/histories_run_report.json';

  final Map<String, SaintSeed> seeds = loadSeeds(seedsPath);
  final List<AuthoringJob> jobs = loadGroundingJobs(
    groundingDir: groundingDir,
    seeds: seeds,
    onlySlugs: onlySlugs,
    limit: limit,
  );
  if (jobs.isEmpty) {
    throw OrchestratorException(
      onlySlugs.isEmpty
          ? 'no grounded jobs found in $groundingDir/manifest.json'
          : 'no grounded job matches --slug ${onlySlugs.join(', ')}',
    );
  }

  final Map<String, dynamic> corpus = readHistories(historiesPath);
  final HistoryOrchestrator orchestrator = HistoryOrchestrator(
    runModel: runModel ?? opencodeModelRunner(),
    authorModel: authorModel,
    crossCheckModels: crossCheckModels,
    concurrency: concurrency,
    crossCheckBatchSize: crossCheckBatchSize,
    log: log,
  );
  log(
    'jobs: ${jobs.length} (${corpus.length} already authored), '
    'concurrency: $concurrency, author: $authorModel',
  );
  final List<EntryOutcome> outcomes = await orchestrator.runJobs(
    jobs,
    existingSlugs: corpus.keys.toSet(),
    sourceClass: sourceClass,
  );

  for (final EntryOutcome outcome in outcomes) {
    if (outcome.status == EntryStatus.accepted && outcome.entry != null) {
      corpus[outcome.slug] = outcome.entry!.toJson();
    }
  }
  File(historiesPath).writeAsStringSync('${_prettyEncoder.convert(corpus)}\n');

  final Map<String, dynamic> report = buildRunReport(
    outcomes: outcomes,
    authorModel: authorModel,
    crossCheckModels: crossCheckModels,
    generatedAt: DateTime.now(),
  );
  File(reportPath).writeAsStringSync('${_prettyEncoder.convert(report)}\n');

  final Map<String, dynamic> counts = report['counts'] as Map<String, dynamic>;
  log(
    'accepted: ${counts['accepted']}, dropped: ${counts['dropped']}, '
    'skipped: ${counts['skipped']}, error: ${counts['error']} '
    '(corpus: ${corpus.length})',
  );
  log('wrote: $historiesPath');
  log('wrote: $reportPath');
  return OrchestratorRun(
    outcomes: outcomes,
    historiesPath: historiesPath,
    reportPath: reportPath,
    corpusSize: corpus.length,
  );
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

const String _usage = '''
Grounded history authoring orchestrator (saint-histories Task 3).

Usage (from the package root):
  dart run tools/histories_orchestrator.dart [options]

Options:
  --slug <slug>        Author only this grounded slug (repeatable).
  --limit <n>          Author at most n new entries this run.
  --concurrency <n>    Entries in flight (default 4; plan range 4-6).
  --batch-size <n>     Entries per cross-check-model batch (default 10).
  --source-class <c>   Source class: catholic-encyclopedia-1907 (default) or
                       wikipedia; selects the grounding directory and the
                       historySource prefix.
  --help               Show this help.

Outputs: data/histories.json, data/histories_run_report.json''';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln(_usage);
    return;
  }
  final List<String> slugs = <String>[];
  int? limit;
  int concurrency = 4;
  int batchSize = 10;
  String sourceClass = 'catholic-encyclopedia-1907';
  for (int i = 0; i < args.length; i++) {
    final String arg = args[i];
    String? value() => i + 1 < args.length ? args[++i] : null;
    switch (arg) {
      case '--slug':
        {
          final String? slug = value();
          if (slug == null) {
            stderr.writeln('histories_orchestrator: --slug needs a value');
            exitCode = 1;
            return;
          }
          slugs.add(slug);
        }
      case '--limit':
        {
          final int? parsed = int.tryParse(value() ?? '');
          if (parsed == null || parsed < 1) {
            stderr.writeln(
              'histories_orchestrator: --limit needs a positive int',
            );
            exitCode = 1;
            return;
          }
          limit = parsed;
        }
      case '--concurrency':
        {
          final int? parsed = int.tryParse(value() ?? '');
          if (parsed == null || parsed < 1) {
            stderr.writeln(
              'histories_orchestrator: --concurrency needs a positive int',
            );
            exitCode = 1;
            return;
          }
          concurrency = parsed > 6 ? 6 : parsed;
        }
      case '--batch-size':
        {
          final int? parsed = int.tryParse(value() ?? '');
          if (parsed == null || parsed < 1) {
            stderr.writeln(
              'histories_orchestrator: --batch-size needs a positive int',
            );
            exitCode = 1;
            return;
          }
          batchSize = parsed;
        }
      case '--source-class':
        {
          final String? cls = value();
          if (cls == null) {
            stderr.writeln(
              'histories_orchestrator: --source-class needs a value',
            );
            exitCode = 1;
            return;
          }
          sourceClass = cls;
        }
      default:
        stderr.writeln('histories_orchestrator: unknown argument "$arg"');
        exitCode = 1;
        return;
    }
  }

  try {
    final OrchestratorRun orchestratorRun = await run(
      onlySlugs: slugs,
      limit: limit,
      concurrency: concurrency,
      crossCheckBatchSize: batchSize,
      sourceClass: sourceClass,
    );
    final bool hasErrors = orchestratorRun.outcomes.any(
      (EntryOutcome outcome) => outcome.status == EntryStatus.error,
    );
    if (hasErrors) {
      stderr.writeln(
        'histories_orchestrator: '
        '${orchestratorRun.outcomes.where((EntryOutcome o) => o.status == EntryStatus.error).length} '
        'entry/entries failed — re-run to retry them',
      );
      exitCode = 1;
    }
  } on OrchestratorException catch (error) {
    stderr.writeln('histories_orchestrator: $error');
    exitCode = 1;
  }
}
