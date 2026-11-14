// CE selection tool (Task 1 of the saint-histories plan).
//
// Fetches the 26 full letter indexes of the 1907-12 Catholic Encyclopedia
// (`https://www.newadvent.org/cathen/{letter}-ce.htm`), parses every
// index-entry line (`title -> article code -> two-line note`), matches the
// seed names in `data/saints_source.json` against them with a strict 1:1
// slug<->article discipline, and writes the three grounding outputs:
//   data/grounding/selection.json         machine selection (pinned shape)
//   data/grounding/selection_review.json  partner-readable summary
//   data/grounding/manual_review.json     quarantined collisions / conflicted
//                                         accepts / weak fuzzy candidates
//
// Match discipline (Global Constraints): 1:1 slug<->article ONLY. Exact
// normalized matches are accepted when uniquely paired; fuzzy candidates
// scoring >= 0.9 are accepted 1:1 BUT only after identity guards (trailing
// Roman-numeral conflict, inverted-surname mismatch, non-person and
// multi-person articles, and seed-bio <-> CE-note grounding) clear;
// collisions and fuzzy candidates below 0.9 quarantine to manual_review.json
// (buckets: `collisions` — article claimed by another slug or unclaimable
// group/non-person/bare-name article, `conflicted` — refused at the accept
// gate with ratio >= 0.9, `fuzzy` — best candidate too weak) and are
// recorded as drops — never auto-shared. A qualified seed (e.g. `St. Adalbert
// of Egmond`) can never resolve to a bare-name CE article (e.g. `Adalbert,
// Saint`): whole-string similarity keeps short articles far below the accept
// floor.
//
// Polite scraping: >= 2.2 s between requests, resumable via a disk cache
// under data/grounding/ce_index/, robots rules honored.
//
// Dev-only: tools/ is never imported by runtime code.
//
// Usage (from the package root):
//   dart run tools/select_ce_matches.dart [--refresh]
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Polite, identifiable UA for all requests to newadvent.org.
const String _userAgent =
    'sancta_via_dev/0.1 (CE selection tool; ground-truth build; contact via repo)';

/// Minimum gap between consecutive requests to newadvent.org.
const Duration _minRequestGap = Duration(milliseconds: 2200);

/// Per-request timeout.
const Duration _requestTimeout = Duration(seconds: 30);

/// Auto-accept floor for fuzzy matches (Global Constraint: < 0.9 quarantines).
const double _fuzzyAccept = 0.9;

/// Manual-review floor: candidates at or above this ratio (but below
/// [_fuzzyAccept]) are surfaced in manual_review.json with their ratio.
const double _fuzzyReview = 0.75;

/// Reason strings recorded in selection.json drops.
const String _reasonNoMatch = 'no-ce-match';
const String _reasonCollision = 'collision-quarantined';
const String _reasonFuzzy = 'fuzzy-quarantined';
const String _reasonFuzzyAmbiguous = 'fuzzy-ambiguous';
const String _reasonConflicted = 'conflicted-quarantined';

/// Causes recorded on manual_review.json conflicted rows.
const String _causeClaimed = 'claimed';
const String _causeAmbiguous = 'ambiguous';

/// The 26 full letter indexes of the Catholic Encyclopedia.
const List<String> _letters = <String>[
  'a',
  'b',
  'c',
  'd',
  'e',
  'f',
  'g',
  'h',
  'i',
  'j',
  'k',
  'l',
  'm',
  'n',
  'o',
  'p',
  'q',
  'r',
  's',
  't',
  'u',
  'v',
  'w',
  'x',
  'y',
  'z',
];

/// Fatal tool error surfaced with exit code 1.
class SelectCeMatchesException implements Exception {
  final String message;

  /// Creates an exception with [message].
  SelectCeMatchesException(this.message);

  @override
  String toString() => message;
}

/// One parsed line of a CE letter index.
class CeEntry {
  /// Article code, e.g. `06255a` for `cathen/06255a.htm`.
  final String code;

  /// Decoded index title, e.g. `Francis of Assisi, Saint`.
  final String title;

  /// Decoded two-line index note.
  final String note;

  /// Creates an entry.
  const CeEntry({required this.code, required this.title, required this.note});
}

/// A slug whose name normalized against a multi-saint (group) article or
/// against a CE article that other slugs also claim — 1:1 discipline
/// forbids auto-sharing any of them.
class CollisionRow {
  final String slug;
  final String name;
  final String ceHead;
  final String ceCode;

  /// Creates a row.
  const CollisionRow({
    required this.slug,
    required this.name,
    required this.ceHead,
    required this.ceCode,
  });
}

/// A slug whose best CE candidate scored in `[0.75, 0.9)` — quarantined.
class FuzzyRow {
  final String slug;
  final String name;
  final String ceHead;
  final double ratio;

  /// Creates a row.
  const FuzzyRow({
    required this.slug,
    required this.name,
    required this.ceHead,
    required this.ratio,
  });
}

/// A slug whose best candidate cleared the accept floor (ratio >= 0.9) but
/// was refused: the article was claimed by an exact matchant (`claimed`),
/// rivals tied at the floor (`ambiguous`), or an identity guard rejected it
/// (`ordinal-conflict`, `surname-mismatch`, `non-person-article`,
/// `multi-person-article`, `no-grounding`). Recorded apart from the
/// below-floor `fuzzy` bucket so the partner read distinguishes "match too
/// weak" from "refused at the accept gate".
class ConflictedRow {
  final String slug;
  final String name;
  final String ceHead;
  final String ceCode;
  final double ratio;
  final String cause;

  /// Creates a row.
  const ConflictedRow({
    required this.slug,
    required this.name,
    required this.ceHead,
    required this.ceCode,
    required this.ratio,
    required this.cause,
  });
}

/// A seed that did not make the selection, with its reason.
class SelectionDrop {
  final String slug;
  final String name;
  final String reason;

  /// Creates a drop.
  const SelectionDrop({
    required this.slug,
    required this.name,
    required this.reason,
  });
}

/// An accepted 1:1 pairing of a seed with a CE article.
class CeMatch {
  final String slug;
  final String name;
  final String ceCode;
  final String ceTitle;
  final String ceNote;
  final int patronageCount;
  final bool featured;

  /// `exact` or `fuzzy` (fuzzy means ratio >= 0.9).
  final String matchType;

  /// Similarity ratio for fuzzy accepts; null for exacts.
  final double? ratio;

  /// Creates a match.
  const CeMatch({
    required this.slug,
    required this.name,
    required this.ceCode,
    required this.ceTitle,
    required this.ceNote,
    required this.patronageCount,
    required this.featured,
    required this.matchType,
    required this.ratio,
  });

  /// Derived article URL.
  String get ceUrl => 'https://www.newadvent.org/cathen/$ceCode.htm';

  /// The pinned selection.json row keys.
  Set<String> get jsonKeys => const <String>{
    'slug',
    'name',
    'ceCode',
    'ceTitle',
    'ceUrl',
    'patronageCount',
    'featured',
  };

  /// selection.json row (pinned shape, ranked).
  Map<String, dynamic> toSelectionJson() {
    return <String, dynamic>{
      'slug': slug,
      'name': name,
      'ceCode': ceCode,
      'ceTitle': ceTitle,
      'ceUrl': ceUrl,
      'patronageCount': patronageCount,
      'featured': featured,
    };
  }

  /// selection_review.json row (human-readable variant).
  Map<String, dynamic> toReviewJson() {
    return <String, dynamic>{
      'slug': slug,
      'name': name,
      'matchType': matchType,
      'ceTitle': ceTitle,
      'ceUrl': ceUrl,
      'ceNote': ceNote,
      'patronageCount': patronageCount,
      'featured': featured,
    };
  }
}

/// The full selection result.
class Selection {
  final String generatedAt;
  final List<CeMatch> matches;
  final List<SelectionDrop> drops;
  final List<CollisionRow> collisions;
  final List<FuzzyRow> fuzzy;
  final List<ConflictedRow> conflicted;
  final Map<String, int> counts;

  /// Creates a selection result.
  const Selection({
    required this.generatedAt,
    required this.matches,
    required this.drops,
    required this.collisions,
    required this.fuzzy,
    required this.conflicted,
    required this.counts,
  });
}

// ---------------------------------------------------------------------------
// Parsing + normalization helpers (pure; exercised by the fixture tests).
// ---------------------------------------------------------------------------

/// Index-entry line shape:
/// `<a href="../cathen/13290a.htm">Sabina, Saint</a> - Martyr in 126<br>`
/// Nav rows, banner links, and prose links never carry the
/// ` - <note><br>` tail and are excluded naturally.
final RegExp _entryPattern = RegExp(
  r'<a\s[^>]*?href="[^"]*?/cathen/([0-9]{5}[a-z])\.htm"[^>]*>'
  r'(.*?)</a>\s*-\s*(.*?)<br\s*/?\s*>',
  dotAll: true,
);

/// Removes inline markup such as the `<strong>` wrappers on index pages.
String stripTags(String input) {
  return input.replaceAll(RegExp(r'<[^>]*>'), '');
}

/// Named entities commonly used on the index pages; the numeric catch-alls
/// in [decodeEntities] cover `&#151;` and friends. Unknown entities are
/// left verbatim so nothing is silently invented.
const Map<String, String> _namedEntities = <String, String>{
  'nbsp': ' ',
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'copy': '©',
  'middot': '·',
  'mdash': '—',
  'ndash': '–',
  'aelig': 'æ',
  'aElig': 'æ',
  'AElig': 'Æ',
  'oelig': 'œ',
  'oElig': 'œ',
  'OElig': 'Œ',
  'oslash': 'ø',
  'Oslash': 'Ø',
  'aring': 'å',
  'Aring': 'Å',
  'auml': 'ä',
  'euml': 'ë',
  'iuml': 'ï',
  'ouml': 'ö',
  'uuml': 'ü',
  'yuml': 'ÿ',
  'Yuml': 'Ÿ',
  'Auml': 'Ä',
  'Euml': 'Ë',
  'Iuml': 'Ï',
  'Ouml': 'Ö',
  'Uuml': 'Ü',
  'szlig': 'ß',
  'aacute': 'á',
  'agrave': 'à',
  'acirc': 'â',
  'atilde': 'ã',
  'Aacute': 'Á',
  'Agrave': 'À',
  'Acirc': 'Â',
  'Atilde': 'Ã',
  'eacute': 'é',
  'egrave': 'è',
  'ecirc': 'ê',
  'Eacute': 'É',
  'Egrave': 'È',
  'Ecirc': 'Ê',
  'iacute': 'í',
  'igrave': 'ì',
  'icirc': 'î',
  'Iacute': 'Í',
  'Igrave': 'Ì',
  'Icirc': 'Î',
  'oacute': 'ó',
  'ograve': 'ò',
  'ocirc': 'ô',
  'otilde': 'õ',
  'Oacute': 'Ó',
  'Ograve': 'Ò',
  'Ocirc': 'Ô',
  'Otilde': 'Õ',
  'uacute': 'ú',
  'ugrave': 'ù',
  'ucirc': 'û',
  'Uacute': 'Ú',
  'Ugrave': 'Ù',
  'Ucirc': 'Û',
  'ntilde': 'ñ',
  'Ntilde': 'Ñ',
  'ccedil': 'ç',
  'Ccedil': 'Ç',
  'yacute': 'ý',
  'Yacute': 'Ý',
  'eth': 'ð',
  'ETH': 'Ð',
  'thorn': 'þ',
  'THORN': 'Þ',
};

/// Legacy Windows-1252 control range: codepoints 0x80-0x9F referenced by
/// `&#151;`-style numeric entities on the New Advent pages (the text
/// predates Unicode and is cp1252-encoded).
const Map<int, String> _cp1252Controls = <int, String>{
  0x80: '€',
  0x82: '‚',
  0x83: 'ƒ',
  0x84: '„',
  0x85: '…',
  0x86: '†',
  0x87: '‡',
  0x88: 'ˆ',
  0x89: '‰',
  0x8A: 'Š',
  0x8B: '‹',
  0x8C: 'Œ',
  0x8E: 'Ž',
  0x91: '‘',
  0x92: '’',
  0x93: '“',
  0x94: '”',
  0x95: '•',
  0x96: '–',
  0x97: '—',
  0x98: '˜',
  0x99: '™',
  0x9A: 'š',
  0x9B: '›',
  0x9C: 'œ',
  0x9E: 'ž',
  0x9F: 'Ÿ',
};

/// Decodes numeric entities (`&#151;`, `&#x26A;`); codepoints in the legacy
/// C1 control range map through Windows-1252, unknown controls are dropped
/// rather than kept invisible; unknown named entities are left verbatim
/// (honesty over invention).
String decodeEntities(String input) {
  String withNumeric = input;
  String decodeNumber(int code) {
    if (code >= 0x20 && (code < 0x7F || code > 0x9F)) {
      return String.fromCharCode(code);
    }
    return _cp1252Controls[code] ?? '';
  }

  withNumeric = withNumeric.replaceAllMapped(
    RegExp(r'&#x([0-9a-fA-F]+);'),
    (Match m) => decodeNumber(int.parse(m.group(1)!, radix: 16)),
  );
  withNumeric = withNumeric.replaceAllMapped(
    RegExp(r'&#(\d+);'),
    (Match m) => decodeNumber(int.parse(m.group(1)!)),
  );
  return withNumeric.replaceAllMapped(
    RegExp(r'&(\w+);'),
    (Match m) => _namedEntities[m.group(1)!] ?? m.group(0)!,
  );
}

/// Latin-1-ish fold table: accented letters fold to their ASCII base so
/// entity-decoded CE titles match seed names containing the raw characters.
const Map<String, String> _foldMap = <String, String>{
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ø': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'ñ': 'n',
  'ç': 'c',
  'ð': 'd',
  'œ': 'oe',
  'æ': 'ae',
  'ß': 'ss',
  'š': 's',
  'ž': 'z',
};

/// Lowercases and strips diacritics via the explicit fold table.
String foldText(String input) {
  final StringBuffer out = StringBuffer();
  for (final int rune in input.toLowerCase().runes) {
    final String character = String.fromCharCode(rune);
    out.write(_foldMap[character] ?? character);
  }
  return out.toString();
}

/// Collapses whitespace runs to single spaces and trims.
String _collapseWhitespace(String input) {
  return input.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Honorific tokens that may occupy a comma part of a CE title on their own
/// (`Francis of Assisi, Saint` / `Leo II, Pope Saint`) or open one
/// (`Haraldson, Saint Olaf`). Multi-part titles such as `Damasus I, Saint,
/// Pope` and `More, Thomas, Saint` hide the identity behind these parts.
const Set<String> _honorificTokens = <String>{
  'saint',
  'saints',
  'st',
  'sts',
  'popes',
  'pope',
  'blessed',
  'bl',
  'ven',
  'venerable',
};

/// Strips honorific tokens from the edges of one comma part (after a leading
/// `the`), e.g. `saint elo` -> `elo`, `the venerable` -> ``, `pope saint` ->
/// ``. Interior tokens (`Mac Lenine` in `Colman Mac Lenine`) are untouched.
String _stripPartHonorifics(String part) {
  final List<String> tokens = _collapseWhitespace(
    part,
  ).split(' ').where((String token) => token.isNotEmpty).toList();
  if (tokens.length > 1 && tokens.first == 'the') {
    tokens.removeAt(0);
  }
  while (tokens.isNotEmpty && _honorificTokens.contains(tokens.first)) {
    tokens.removeAt(0);
  }
  while (tokens.isNotEmpty && _honorificTokens.contains(tokens.last)) {
    tokens.removeLast();
  }
  return _collapseWhitespace(tokens.join(' '));
}

/// Parses one letter-index page into its article entries.
List<CeEntry> parseCeIndex(String html) {
  final List<CeEntry> entries = <CeEntry>[];
  for (final RegExpMatch match in _entryPattern.allMatches(html)) {
    final String title = _collapseWhitespace(
      decodeEntities(stripTags(match.group(2)!)),
    );
    final String note = _collapseWhitespace(
      decodeEntities(stripTags(match.group(3)!)),
    );
    if (title.isEmpty || note.isEmpty) {
      continue;
    }
    entries.add(CeEntry(code: match.group(1)!, title: title, note: note));
  }
  return entries;
}

/// Folds a decoded name/title to the normalized base form: case- and
/// accent-folded, punctuation replaced by spaces, commas kept (for the
/// surname-reorder partition), whitespace collapsed.
String _normalizeBase(String raw) {
  String base = foldText(decodeEntities(stripTags(raw.toLowerCase())));
  base = base.replaceAll(RegExp(r"[^a-z0-9,]"), ' ');
  base = base.replaceAll(RegExp(r'\s*,\s*'), ',');
  base = _collapseWhitespace(base);
  base = base.replaceAll(RegExp(r'^[\s,]+|[\s,]+$'), '');
  return base;
}

/// Builds every match key for a seed name or CE title: honorific strips on
/// both sides (`St. X` / `X, Saint`), honorific-part stripping on multi-part
/// comma titles (`Damasus I, Saint, Pope` -> `damasus i`, `More, Thomas,
/// Saint` -> `thomas more`), surname-reorder for (residual) two-part comma
/// titles, a comma-free key, an article-free variant with standalone `of`
/// removed, and a leading-article variant (`The X`). Matching is set
/// equality across variants, so `St. Francis of Assisi`, `Francis of Assisi,
/// Saint`, and `Loyola, Ignatius`/`Ignatius Loyola` all pair correctly.
Set<String> nameVariants(String raw) {
  final String base = _normalizeBase(raw);
  final Set<String> out = <String>{};

  void add(String value) {
    final String cleaned = value.trim();
    if (cleaned.length < 2) {
      return;
    }
    out.add(cleaned.replaceAll(RegExp(r'\s*,\s*'), ' ').trim());
  }

  final List<String> commaParts =
      base.split(',').map((String part) => part.trim()).toList()
        ..removeWhere((String part) => part.isEmpty);
  // Honorific-stripped parts: `More, Thomas, Saint` -> [more, thomas] (the
  // multi-honorific forms that hid correct matches); `Colman, Saint Elo` ->
  // [colman, elo].
  final List<String> strippedParts = <String>[
    for (final String part in commaParts) _stripPartHonorifics(part),
  ]..removeWhere((String part) => part.isEmpty);
  if (strippedParts.isEmpty) {
    strippedParts.addAll(commaParts);
  }
  final Set<String> reorderForms = <String>{};
  if (base.trim().isNotEmpty) {
    reorderForms.add(base);
    final String unstrippedJoin = _collapseWhitespace(commaParts.join(' '));
    if (unstrippedJoin.isNotEmpty) {
      reorderForms.add(unstrippedJoin);
    }
    if (commaParts.length == 2) {
      reorderForms.add('${commaParts[1]} ${commaParts[0]}');
    }
  }
  reorderForms.add(strippedParts.join(','));
  if (strippedParts.length == 2) {
    reorderForms.add('${strippedParts[1]} ${strippedParts[0]}');
  }
  reorderForms.removeWhere((String form) => form.trim().isEmpty);

  final RegExp leadHonorific = RegExp(
    r'^(saints?|st|blessed|bl|ven|venerable|pope)\s+',
  );
  final RegExp leadArticle = RegExp(r'^the\s+');
  final RegExp trailHonorific = RegExp(r',?\s*(saints?|popes?)$');

  String stripLead(String value) {
    String current = value;
    for (int pass = 0; pass < 3; pass++) {
      final String stripped = current
          .replaceAll(leadHonorific, ' ')
          .replaceAll(leadArticle, ' ')
          .trim();
      if (stripped == current) {
        break;
      }
      current = stripped.trim();
    }
    return current;
  }

  String stripTrail(String value) {
    return value.replaceAll(trailHonorific, ' ').trim();
  }

  String stripOf(String value) {
    return value
        .split(' ')
        .where((String token) => token != 'of')
        .join(' ')
        .trim();
  }

  for (final String reorderForm in reorderForms) {
    final String trailingStripped = stripTrail(reorderForm);
    final Set<String> candidates = <String>{
      reorderForm,
      trailingStripped,
      stripLead(reorderForm),
      stripLead(trailingStripped),
    };
    for (final String candidate in candidates.toList()) {
      final String ofStripped = stripOf(candidate);
      candidates.add(ofStripped);
      candidates.add(stripLead(ofStripped));
    }
    for (final String candidate in candidates) {
      add(candidate);
    }
  }
  return out;
}

/// Levenshtein-based whole-string similarity in [0.0, 1.0]:
/// `1 - distance / max(len)`. Whole-string (never partial) so a short
/// bare-name article such as `Adalbert` scores LOW against a qualified
/// seed such as `St. Adalbert of Egmond` and can never auto-match.
double similarity(String a, String b) {
  if (a == b) {
    return 1.0;
  }
  if (a.isEmpty || b.isEmpty) {
    return 0.0;
  }
  final int n = a.length;
  final int m = b.length;
  List<int> previous = List<int>.generate(m + 1, (int i) => i);
  List<int> current = List<int>.filled(m + 1, 0);
  for (int i = 1; i <= n; i++) {
    current[0] = i;
    for (int j = 1; j <= m; j++) {
      final int substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
      final int deletion = previous[j] + 1;
      final int insertion = current[j - 1] + 1;
      int best = substitution;
      if (deletion < best) {
        best = deletion;
      }
      if (insertion < best) {
        best = insertion;
      }
      current[j] = best;
    }
    final List<int> swap = previous;
    previous = current;
    current = swap;
  }
  final int distance = previous[m];
  return 1.0 - distance / (n > m ? n : m);
}

/// Group (multi-saint) article detection: plural `, Saints` titles, or an
/// index note advertising several saints of one name under a single article
/// (`Discuss(es) (four|several…) saints of this name`, `several saints
/// named …`, `other saints of this name`), or a shared family-name article
/// (`The name of a fifth-century … family, three of whose representatives…`).
bool isGroupArticle(CeEntry entry) {
  final String title = foldText(entry.title);
  if (RegExp(r',\s*saints$').hasMatch(title) || title.endsWith(' saints')) {
    return true;
  }
  final String note = foldText(entry.note);
  return RegExp(
    r'several saints (of|named)|saints of this name|other saints of this name'
    r'|^the name of [a-z\- ]{0,32}family\b',
  ).hasMatch(note);
}

/// Non-person article detection: the index line describes a term, object,
/// or place rather than a biographical subject. `St. Deogratias` must never
/// claim `Deo Gratias — An old liturgical formula…`.
bool isNonPersonArticle(CeEntry entry) {
  final String note = foldText(entry.note);
  return RegExp(
    r'liturgical formula'
    r'|\ba (?:kind|type) of\b'
    r'|^the (?:greek|latin|english) word '
    r'|^archdiocese and (?:city|diocese)\b',
  ).hasMatch(note);
}

/// Strips leading honorific tokens from a seed display name and returns its
/// identity tokens (`Pope St. Caius` -> {caius}).
Set<String> seedNameTokens(String name) {
  final List<String> tokens = _collapseWhitespace(
    foldText(name.toLowerCase()).replaceAll(RegExp(r'[^a-z0-9\s]'), ' '),
  ).split(' ');
  while (tokens.isNotEmpty && _honorificTokens.contains(tokens.first)) {
    tokens.removeAt(0);
  }
  while (tokens.isNotEmpty && _honorificTokens.contains(tokens.last)) {
    tokens.removeLast();
  }
  return <String>{
    for (final String token in tokens)
      if (token.isNotEmpty) token,
  };
}

/// Slug tokens that qualify the seed's identity beyond its display name
/// (`moses-bishop-of-the-arabs` -> {bishop, of, the, arabs}). Pure
/// honorific prefixes (`saint-…`) are display echoes, not qualifiers; a
/// `pope-` prefix IS a qualifier (popes must find a Pope-marked article).
Set<String> slugQualifierTokens(String slug, String name) {
  final Set<String> nameTokens = seedNameTokens(name);
  final Set<String> slugTokens = foldText(
    slug.toLowerCase(),
  ).split('-').where((String token) => token.isNotEmpty).toSet();
  slugTokens.removeAll(nameTokens);
  slugTokens.removeAll(const <String>{'saint', 'saints', 'st', 'sts'});
  return slugTokens;
}

/// True when the seed's display name is a bare single token, its slug carries
/// identity qualifiers beyond the name, and the CE article title carries no
/// canonization marker of its own — a bare-name collision such as
/// `St. Moses` (slug `moses-bishop-of-the-arabs`) matching CE's `Moses` (the
/// Hebrew liberator/prophet). The qualified seed cannot claim the bare
/// identity of just any same-named article.
bool isBareNameCollision({
  required String slug,
  required String name,
  required CeEntry entry,
}) {
  final Set<String> nameTokens = seedNameTokens(name);
  if (nameTokens.isEmpty || nameTokens.length != 1) {
    return false;
  }
  if (slugQualifierTokens(slug, name).isEmpty) {
    return false;
  }
  return !RegExp(
    r'(saints?|popes?|blessed|venerable|st)\b',
    caseSensitive: false,
  ).hasMatch(foldText(entry.title));
}

/// Value of a valid roman-numeral token (`ii` -> 2), or null when the token
/// is not a plausible trailing ordinal.
int? romanNumeralValue(String token) {
  if (token.length > 7 || !RegExp(r'^[ivxlcdm]+$').hasMatch(token)) {
    return null;
  }
  const Map<String, int> values = <String, int>{
    'i': 1,
    'v': 5,
    'x': 10,
    'l': 50,
    'c': 100,
    'd': 500,
    'm': 1000,
  };
  final RegExp forms = RegExp(
    r'^m*(?:cm|cd|d?c{0,3})(?:xc|xl|l?x{0,3})(?:ix|iv|v?i{0,3})$',
  );
  if (!forms.hasMatch(token)) {
    return null;
  }
  int total = 0;
  for (int i = 0; i < token.length; i++) {
    total += values[token[i]] ?? 0;
  }
  return total;
}

/// Ordinal guard: a fuzzy match whose names carry trailing Roman numerals
/// (`Damasus I` vs `Damasus II`) may never auto-accept when the articles are
/// different claimants of the name — the ordinals must agree.
bool ordinalsConflict(String seedVariant, String entryVariant) {
  final List<String> seedTokens = seedVariant.split(' ');
  final List<String> entryTokens = entryVariant.split(' ');
  if (seedTokens.isEmpty || entryTokens.isEmpty) {
    return false;
  }
  final int? seedOrdinal = romanNumeralValue(seedTokens.last);
  if (seedOrdinal == null) {
    return false;
  }
  final int? entryOrdinal = romanNumeralValue(entryTokens.last);
  if (entryOrdinal == null) {
    return false;
  }
  return seedOrdinal != entryOrdinal;
}

/// Rare-term token set for grounding: letters only, folded/lowercased, at
/// least five characters, common connective and ecclesiastical boilerplate
/// removed. The overlap between a seed's biography and the CE index note is
/// the identity evidence a fuzzy candidate must clear.
const Set<String> _groundingStopwords = <String>{
  'about',
  'after',
  'among',
  'also',
  'their',
  'there',
  'these',
  'those',
  'under',
  'until',
  'which',
  'while',
  'where',
  'whose',
  'christ',
  'christian',
  'church',
  'churches',
  'greek',
  'latin',
  'roman',
  'rome',
  'great',
  'saints',
  'popes',
  'venerable',
  'blessed',
  'called',
  'known',
  'lived',
  'century',
  'other',
  'first',
  'second',
  'third',
  'writings',
};

Set<String> groundingTokens(String text) {
  return <String>{
    for (final Match match in RegExp(
      r'[a-z]{5,}',
    ).allMatches(foldText(text.toLowerCase())))
      if (!_groundingStopwords.contains(match.group(0)!)) match.group(0)!,
  };
}

/// Number of rare terms shared between the seed biography and the CE index
/// note (identity grounding for fuzzy matches).
int groundingCount(String? bio, String ceNote) {
  if (bio == null || bio.isEmpty) {
    return 0;
  }
  return groundingTokens(bio).intersection(groundingTokens(ceNote)).length;
}

/// The pre-comma surname token of an inverted CE title (`Moore, Thomas` ->
/// `moore`; `Kostka, Saint Stanislas` -> `kostka`), or null for forward
/// titles and multi-token pre-comma parts (`Damasus II, Pope`).
String? invertedSurnameToken(String ceTitle) {
  final int comma = ceTitle.indexOf(',');
  if (comma < 1) {
    return null;
  }
  final String part = _stripPartHonorifics(ceTitle.substring(0, comma));
  final List<String> tokens = part.split(' ');
  if (tokens.length != 1 || tokens.single.length < 3) {
    return null;
  }
  return foldText(tokens.single.toLowerCase());
}

// ---------------------------------------------------------------------------
// Selection core
// ---------------------------------------------------------------------------

/// Full selection over the [saints] seed maps (snapshot format) and the
/// parsed [entries]. See [Selection] for the produced structure;
/// [toSelectionJson] / [toReviewJson] / [toManualReviewJson] pin the file
/// shapes.
Selection buildSelection({
  required List<Map<String, dynamic>> saints,
  required List<CeEntry> entries,
}) {
  // Article identity is the code (a few articles are cross-listed).
  final Map<String, CeEntry> entryByCode = <String, CeEntry>{};
  final List<String> sortedCodes = <String>[];
  for (final CeEntry entry in entries) {
    if (!entryByCode.containsKey(entry.code)) {
      entryByCode[entry.code] = entry;
      sortedCodes.add(entry.code);
    }
  }
  sortedCodes.sort();

  // Exact-key index: normalized variant -> article codes.
  final Map<String, Set<String>> exactIndex = <String, Set<String>>{};
  for (final String code in sortedCodes) {
    for (final String variant in nameVariants(entryByCode[code]!.title)) {
      exactIndex.putIfAbsent(variant, () => <String>{}).add(code);
    }
  }

  // Stage 1: raw exact candidates per slug (empty set -> fuzzy stage).
  final Set<String> groupCodes = <String>{
    for (final String code in sortedCodes)
      if (isGroupArticle(entryByCode[code]!)) code,
  };
  final Map<String, Map<String, dynamic>> saintBySlug =
      <String, Map<String, dynamic>>{};
  final Map<String, List<String>> exactCandidates = <String, List<String>>{};
  for (final Map<String, dynamic> saint in saints) {
    final String slug = saint['slug'] as String;
    final String name = saint['name'] as String;
    saintBySlug[slug] = saint;
    final Set<String> codes = <String>{};
    for (final String variant in nameVariants(name)) {
      codes.addAll(exactIndex[variant] ?? const <String>{});
    }
    exactCandidates[slug] = codes.toList()..sort();
  }
  final List<String> slugs = saintBySlug.keys.toList()..sort();

  // Stage 2: article -> slugs. Any article claimed by 2+ distinct slugs
  // quarantines ALL of them (pinned collision semantics: never auto-shared).
  final Map<String, Set<String>> slugsPerCode = <String, Set<String>>{};
  for (final String slug in slugs) {
    for (final String code in exactCandidates[slug]!) {
      slugsPerCode.putIfAbsent(code, () => <String>{}).add(slug);
    }
  }
  final Set<String> collidedSlugs = <String>{};
  slugsPerCode.forEach((String code, Set<String> claimants) {
    if (claimants.length > 1) {
      collidedSlugs.addAll(claimants);
    }
  });

  // Stage 3: fuzzy candidates for slugs with no exact candidate at all.
  // Compared only against entries sharing a first letter with some seed
  // variant and within a length band that could still reach the review
  // floor, keeping the quadratic cost bounded.
  final Map<String, _FuzzyCandidate> fuzzyBest = <String, _FuzzyCandidate>{};
  for (final String slug in slugs) {
    if (exactCandidates[slug]!.isNotEmpty) {
      continue;
    }
    final Set<String> seedVariants = nameVariants(
      saintBySlug[slug]!['name'] as String,
    );
    _FuzzyCandidate best = const _FuzzyCandidate(
      code: '',
      title: '',
      ratio: 0.0,
      equalBest: 0,
      seedVariant: '',
      entryVariant: '',
    );
    for (final String code in sortedCodes) {
      final CeEntry entry = entryByCode[code]!;
      final Set<String> entryVariants = nameVariants(entry.title);
      bool shareInitial = false;
      for (final String seedVariant in seedVariants) {
        for (final String entryVariant in entryVariants) {
          if (entryVariant[0] == seedVariant[0]) {
            shareInitial = true;
            break;
          }
        }
        if (shareInitial) {
          break;
        }
      }
      if (!shareInitial) {
        continue;
      }
      double localRatio = 0.0;
      String localSeedVariant = '';
      String localEntryVariant = '';
      for (final String seedVariant in seedVariants) {
        for (final String entryVariant in entryVariants) {
          final int maxLen = entryVariant.length > seedVariant.length
              ? entryVariant.length
              : seedVariant.length;
          final int lengthGap = (entryVariant.length - seedVariant.length)
              .abs();
          // 1 - gap/maxLen bounds the best possible ratio; skip pairs that
          // could not reach even the manual-review floor.
          if (lengthGap >= maxLen * (1 - _fuzzyReview)) {
            continue;
          }
          final double ratio = similarity(seedVariant, entryVariant);
          if (ratio > localRatio + 1e-12) {
            localRatio = ratio;
            localSeedVariant = seedVariant;
            localEntryVariant = entryVariant;
          }
        }
      }
      if (localRatio < _fuzzyReview) {
        continue;
      }
      if (localRatio > best.ratio + 1e-12) {
        best = _FuzzyCandidate(
          code: code,
          title: entry.title,
          ratio: localRatio,
          equalBest: 1,
          seedVariant: localSeedVariant,
          entryVariant: localEntryVariant,
        );
      } else if (localRatio >= _fuzzyAccept &&
          (localRatio - best.ratio).abs() <= 1e-12) {
        best = _FuzzyCandidate(
          code: best.code,
          title: best.title,
          ratio: best.ratio,
          equalBest: best.equalBest + 1,
          seedVariant: best.seedVariant,
          entryVariant: best.entryVariant,
        );
      }
    }
    if (best.code.isNotEmpty) {
      fuzzyBest[slug] = best;
    }
  }

  // Stage 4: 1:1 arbitration across BOTH matchers. A fuzzy accept must not
  // land on an article the exact stage already claims (e.g. `St. Finan of
  // Lindisfarne` scoring 0.90 against the article that `St. Aidan of
  // Lindisfarne` matched exactly). Claims are unioned per article code; the
  // exact claimant keeps the article, the losing fuzzy accept quarantines.
  final Map<String, Set<String>> claimsPerCode = <String, Set<String>>{};
  exactCandidates.forEach((String slug, List<String> codes) {
    for (final String code in codes) {
      claimsPerCode.putIfAbsent(code, () => <String>{}).add(slug);
    }
  });
  fuzzyBest.forEach((String slug, _FuzzyCandidate candidate) {
    if (candidate.isAccept) {
      claimsPerCode.putIfAbsent(candidate.code, () => <String>{}).add(slug);
    }
  });
  final Set<String> fuzzyConflictedSlugs = <String>{};
  claimsPerCode.forEach((String code, Set<String> claimants) {
    if (claimants.length > 1) {
      for (final String claimant in claimants) {
        // Exact-side multi-claims are already handled by the exact
        // collision stage; only fuzzy losers are resolved here.
        if (exactCandidates[claimant]!.isEmpty) {
          fuzzyConflictedSlugs.add(claimant);
        }
      }
    }
  });

  // Stage 5: assembly. Non-person articles (a liturgical formula, a word,
  // an object) share the unclaimable-article discipline with group articles.
  final Set<String> nonPersonCodes = <String>{
    for (final String code in sortedCodes)
      if (isNonPersonArticle(entryByCode[code]!)) code,
  };
  final List<CeMatch> matches = <CeMatch>[];
  final List<SelectionDrop> drops = <SelectionDrop>[];
  final List<CollisionRow> collisions = <CollisionRow>[];
  final List<FuzzyRow> fuzzyRows = <FuzzyRow>[];
  final List<ConflictedRow> conflictedRows = <ConflictedRow>[];

  void quarantineArticle(
    Map<String, dynamic> saint,
    Iterable<String> codes,
    String reason,
  ) {
    final String slug = saint['slug'] as String;
    final String name = saint['name'] as String;
    drops.add(SelectionDrop(slug: slug, name: name, reason: reason));
    for (final String code in codes) {
      collisions.add(
        CollisionRow(
          slug: slug,
          name: name,
          ceHead: entryByCode[code]!.title,
          ceCode: code,
        ),
      );
    }
  }

  for (final String slug in slugs) {
    final Map<String, dynamic> saint = saintBySlug[slug]!;
    final String name = saint['name'] as String;
    final bool featured = saint['featured'] as bool? ?? false;
    final Object? patronages = saint['patronages'];
    final int patronageCount = patronages is List<Object?>
        ? patronages.length
        : 0;

    final List<String> codes = exactCandidates[slug]!;
    final bool articleCollision = collidedSlugs.contains(slug);
    final bool groupOnly =
        codes.length == 1 &&
        (groupCodes.contains(codes.single) ||
            nonPersonCodes.contains(codes.single));
    final _FuzzyCandidate? fuzzy = fuzzyBest[slug];

    if (codes.length > 1 ||
        articleCollision ||
        (codes.isNotEmpty && groupOnly)) {
      drops.add(
        SelectionDrop(slug: slug, name: name, reason: _reasonCollision),
      );
      for (final String code in codes) {
        final CeEntry entry = entryByCode[code]!;
        collisions.add(
          CollisionRow(
            slug: slug,
            name: name,
            ceHead: entry.title,
            ceCode: code,
          ),
        );
      }
      continue;
    }
    if (codes.length == 1) {
      final String code = codes.single;
      final CeEntry entry = entryByCode[code]!;
      // Bare-name guard: a qualified slug claiming the bare identity of a
      // marker-less CE title (`moses-bishop-of-the-arabs` -> `Moses`, the
      // Egyptian/prophet article) is a wrong-person match.
      if (isBareNameCollision(slug: slug, name: name, entry: entry)) {
        quarantineArticle(saint, <String>[code], _reasonCollision);
        continue;
      }
      matches.add(
        CeMatch(
          slug: slug,
          name: name,
          ceCode: code,
          ceTitle: entry.title,
          ceNote: entry.note,
          patronageCount: patronageCount,
          featured: featured,
          matchType: 'exact',
          ratio: null,
        ),
      );
      continue;
    }
    if (fuzzy != null) {
      final CeEntry fuzzyEntry = entryByCode[fuzzy.code]!;
      // Guards only gate a candidate that would otherwise be accepted;
      // a below-floor candidate quarantines on weakness alone.
      final bool claimed =
          fuzzy.isAccept && fuzzyConflictedSlugs.contains(slug);
      final bool ambiguous = fuzzy.equalBest > 1;
      final String? guardCause = fuzzy.isAccept && !claimed && !ambiguous
          ? fuzzyGuardRefusal(
              saint: saint,
              entry: fuzzyEntry,
              seedVariant: fuzzy.seedVariant,
              entryVariant: fuzzy.entryVariant,
            )
          : null;
      if (fuzzy.isAccept && !claimed && !ambiguous && guardCause == null) {
        matches.add(
          CeMatch(
            slug: slug,
            name: name,
            ceCode: fuzzy.code,
            ceTitle: fuzzy.title,
            ceNote: fuzzyEntry.note,
            patronageCount: patronageCount,
            featured: featured,
            matchType: 'fuzzy',
            ratio: fuzzy.ratio,
          ),
        );
        continue;
      }
      // Losing fuzzy accepts (article taken by an exact claimant), guard-
      // refused accepts, ambiguous multi-candidates, and review-band
      // candidates quarantine; the review band (< 0.9) stays in the `fuzzy`
      // bucket, every >= 0.9 refusal lands in `conflicted`.
      String cause;
      String reason;
      if (claimed) {
        cause = _causeClaimed;
        reason = _reasonCollision;
      } else if (ambiguous) {
        cause = _causeAmbiguous;
        reason = _reasonFuzzyAmbiguous;
      } else if (guardCause != null) {
        cause = guardCause;
        reason = _reasonConflicted;
      } else {
        cause = 'review-band';
        reason = _reasonFuzzy;
      }
      drops.add(SelectionDrop(slug: slug, name: name, reason: reason));
      if (reason == _reasonFuzzy) {
        fuzzyRows.add(
          FuzzyRow(
            slug: slug,
            name: name,
            ceHead: fuzzy.title,
            ratio: fuzzy.ratio,
          ),
        );
      } else {
        conflictedRows.add(
          ConflictedRow(
            slug: slug,
            name: name,
            ceHead: fuzzy.title,
            ceCode: fuzzy.code,
            ratio: fuzzy.ratio,
            cause: cause,
          ),
        );
      }
      continue;
    }
    drops.add(SelectionDrop(slug: slug, name: name, reason: _reasonNoMatch));
  }

  // Ranking: featured first, then patronageCount desc, then name, then slug
  // (the slug tie-break keeps the total order deterministic).
  matches.sort((CeMatch a, CeMatch b) {
    final int featuredCmp = (a.featured ? 0 : 1).compareTo(b.featured ? 0 : 1);
    if (featuredCmp != 0) {
      return featuredCmp;
    }
    final int patronageCmp = b.patronageCount.compareTo(a.patronageCount);
    if (patronageCmp != 0) {
      return patronageCmp;
    }
    final int nameCmp = foldText(a.name).compareTo(foldText(b.name));
    if (nameCmp != 0) {
      return nameCmp;
    }
    return a.slug.compareTo(b.slug);
  });

  final int matched = matches.length;
  return Selection(
    generatedAt: DateTime.now().toUtc().toIso8601String(),
    matches: matches,
    drops: drops,
    collisions: collisions,
    fuzzy: fuzzyRows,
    conflicted: conflictedRows,
    counts: <String, int>{
      'seeds': slugs.length,
      'matched': matched,
      'dropped': slugs.length - matched,
    },
  );
}

/// Internal per-slug fuzzy bookkeeping.
class _FuzzyCandidate {
  final String code;
  final String title;
  final double ratio;

  /// Number of entries tied at the best ratio (only meaningful when the
  /// best ratio clears the accept floor).
  final int equalBest;

  /// The variant pair achieving the best ratio — identity guards read this
  /// pair (ordinal tokens, inverted surnames).
  final String seedVariant;
  final String entryVariant;

  /// Creates a candidate.
  const _FuzzyCandidate({
    required this.code,
    required this.title,
    required this.ratio,
    required this.equalBest,
    required this.seedVariant,
    required this.entryVariant,
  });

  /// Whether this ratio clears the auto-accept floor (guards may still
  /// refuse the accept; see [_fuzzyGuardRefusal]).
  bool get isAccept => ratio >= _fuzzyAccept && equalBest == 1;
}

/// Refusal cause for a would-be fuzzy accept, or null when every identity
/// guard clears. Guards, in order:
///   * trailing Roman-numeral conflict (`Damasus I` vs `Damasus II`),
///   * inverted-surname mismatch on comma-repaired CE titles (`Moore, Thomas`
///     vs `St. Thomas More`) unless 2+ grounding terms rescue it,
///   * non-person and multi-person (group/family) articles,
///   * grounding: the seed biography and the CE note must share at least one
///     rare term (skipped when the seed carries no biography).
String? fuzzyGuardRefusal({
  required Map<String, dynamic> saint,
  required CeEntry entry,
  required String seedVariant,
  required String entryVariant,
}) {
  if (ordinalsConflict(seedVariant, entryVariant)) {
    return 'ordinal-conflict';
  }
  final String? surname = invertedSurnameToken(entry.title);
  final Object? bio = saint['bio'];
  if (surname != null) {
    final bool surnameInSeed = seedNameTokens(
      saint['name'] as String,
    ).contains(surname);
    if (!surnameInSeed) {
      final bool bioRescue =
          bio is String &&
          bio.isNotEmpty &&
          groundingCount(bio, entry.note) >= 2;
      if (!bioRescue) {
        return 'surname-mismatch';
      }
    }
  }
  if (isNonPersonArticle(entry)) {
    return 'non-person-article';
  }
  if (isGroupArticle(entry)) {
    return 'multi-person-article';
  }
  if (bio is! String || bio.isEmpty) {
    return null;
  }
  if (groundingCount(bio, entry.note) < 1) {
    return 'no-grounding';
  }
  return null;
}

// ---------------------------------------------------------------------------
// Output shapes (pinned by the plan)
// ---------------------------------------------------------------------------

/// selection.json payload (pinned shape).
Map<String, dynamic> toSelectionJson(Selection selection) {
  return <String, dynamic>{
    'generatedAt': selection.generatedAt,
    'matches': <Map<String, dynamic>>[
      for (final CeMatch match in selection.matches) match.toSelectionJson(),
    ],
    'drops': <Map<String, String>>[
      for (final SelectionDrop drop in selection.drops)
        <String, String>{'name': drop.name, 'reason': drop.reason},
    ],
    'counts': <String, int>{
      'seeds': selection.counts['seeds']!,
      'matched': selection.counts['matched']!,
      'dropped': selection.counts['dropped']!,
    },
  };
}

/// manual_review.json payload (pinned shape).
Map<String, dynamic> toManualReviewJson(Selection selection) {
  return <String, dynamic>{
    'collisions': <Map<String, String>>[
      for (final CollisionRow row in selection.collisions)
        <String, String>{
          'slug': row.slug,
          'name': row.name,
          'ceHead': row.ceHead,
          'ceCode': row.ceCode,
        },
    ],
    'conflicted': <Map<String, dynamic>>[
      for (final ConflictedRow row in selection.conflicted)
        <String, dynamic>{
          'slug': row.slug,
          'name': row.name,
          'ceHead': row.ceHead,
          'ceCode': row.ceCode,
          'ratio': (row.ratio * 10000).roundToDouble() / 10000,
          'cause': row.cause,
        },
    ],
    'fuzzy': <Map<String, dynamic>>[
      for (final FuzzyRow row in selection.fuzzy)
        <String, dynamic>{
          'slug': row.slug,
          'name': row.name,
          'ceHead': row.ceHead,
          'ratio': (row.ratio * 10000).roundToDouble() / 10000,
        },
    ],
  };
}

/// selection_review.json payload (human-readable: name + 2-line CE note).
Map<String, dynamic> toReviewJson(Selection selection) {
  return <String, dynamic>{
    'generatedAt': selection.generatedAt,
    'counts': <String, int>{
      'seeds': selection.counts['seeds']!,
      'matched': selection.counts['matched']!,
      'dropped': selection.counts['dropped']!,
    },
    'drops': <Map<String, String>>[
      for (final SelectionDrop drop in selection.drops)
        <String, String>{'name': drop.name, 'reason': drop.reason},
    ],
    'matches': <Map<String, dynamic>>[
      for (final CeMatch match in selection.matches) match.toReviewJson(),
    ],
  };
}

// ---------------------------------------------------------------------------
// IO + main
// ---------------------------------------------------------------------------

/// Pretty JSON encoder used for all grounding outputs.
const JsonEncoder _prettyEncoder = JsonEncoder.withIndent('  ');

/// Serializes [data] to [path], pretty-printed with a trailing newline.
void _writeJson(String path, Object? data) {
  File(path).writeAsStringSync('${_prettyEncoder.convert(data)}\n');
}

/// Reads seeds from [path] (snapshot format: `{"saints": [...]}`).
List<Map<String, dynamic>> loadSeeds(String path) {
  final Map<String, dynamic> decoded =
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return (decoded['saints'] as List<dynamic>).cast<Map<String, dynamic>>();
}

/// Tops up the pacing gap so the next request starts at least
/// [_minRequestGap] after the last one started.
Future<void> _pace(Stopwatch clock) async {
  final int remaining =
      _minRequestGap.inMilliseconds - clock.elapsedMilliseconds;
  if (remaining > 0) {
    await Future<void>.delayed(Duration(milliseconds: remaining));
  }
}

/// GET with the polite UA and timeout; returns the response.
Future<http.Response> _get(Uri url) {
  return http
      .get(url, headers: <String, String>{'User-Agent': _userAgent})
      .timeout(_requestTimeout);
}

/// Fetches [url] with one polite retry (pacing honored before every
/// attempt, including retries), returning the body on HTTP 200.
Future<String> _fetchBody(
  Uri url,
  Set<String> disallowPrefixes,
  Stopwatch pacingClock,
) async {
  for (final String prefix in disallowPrefixes) {
    if (prefix.isNotEmpty && url.path.startsWith(prefix)) {
      throw SelectCeMatchesException('robots.txt disallows: ${url.path}');
    }
  }
  String lastError = '';
  for (int attempt = 0; attempt < 2; attempt++) {
    await _pace(pacingClock);
    pacingClock.reset();
    try {
      final http.Response response = await _get(url);
      if (response.statusCode == 200) {
        return response.body;
      }
      lastError = 'HTTP ${response.statusCode}';
    } catch (error) {
      lastError = error.toString();
    }
  }
  throw SelectCeMatchesException('$lastError for ${url.path}');
}

/// Parses `Disallow:` prefixes for the `User-agent: *` block.
Set<String> parseRobotsDisallows(String robotsBody) {
  final Set<String> disallows = <String>{};
  bool appliesToAll = false;
  for (final String rawLine in robotsBody.split('\n')) {
    final String line = rawLine.trim();
    if (line.startsWith('User-agent:')) {
      appliesToAll = line.substring('User-agent:'.length).trim() == '*';
    } else if (appliesToAll && line.startsWith('Disallow:')) {
      final String path = line.substring('Disallow:'.length).trim();
      if (path.isNotEmpty) {
        disallows.add(path);
      }
    }
  }
  return disallows;
}

/// Loads (or fetches once and caches) robots.txt and returns the Disallow
/// prefixes that apply to our requests. Async, called once from `main`.
Future<Set<String>> loadDisallowPrefixes({
  required Directory ceCacheDir,
  required Stopwatch pacingClock,
}) async {
  final File robotsFile = File('${ceCacheDir.path}/robots.txt');
  if (robotsFile.existsSync()) {
    return parseRobotsDisallows(robotsFile.readAsStringSync());
  }
  final String body = await _fetchBody(
    Uri.parse('https://www.newadvent.org/robots.txt'),
    const <String>{},
    pacingClock,
  );
  robotsFile.writeAsStringSync('$body\n');
  await _pace(pacingClock);
  return parseRobotsDisallows(body);
}

/// Runs the selection end to end, fetching (and caching) the 26 full letter
/// indexes as needed.
Future<Selection?> run({bool refresh = false}) async {
  final Directory packageRoot = Directory.current;
  final String dataDir = '${packageRoot.path}/data';
  final String groundingDir = '$dataDir/grounding';
  final String ceCacheDir = '$groundingDir/ce_index';
  Directory(ceCacheDir).createSync(recursive: true);

  final List<Map<String, dynamic>> saints = loadSeeds(
    '$dataDir/saints_source.json',
  );
  stdout.writeln('seeds loaded: ${saints.length}');

  final Stopwatch pacingClock = Stopwatch();
  final Set<String> disallows = await loadDisallowPrefixes(
    ceCacheDir: Directory(ceCacheDir),
    pacingClock: pacingClock,
  );
  for (final String prefix in disallows) {
    if (prefix.isNotEmpty && '/cathen/a-ce.htm'.startsWith(prefix)) {
      throw SelectCeMatchesException(
        'robots.txt would disallow /cathen/: $prefix',
      );
    }
  }
  stdout.writeln('robots disallow prefixes: ${disallows.toList()}');

  final Map<String, String> pageByLetter = <String, String>{};
  for (final String letter in _letters) {
    final File cached = File('$ceCacheDir/$letter-ce.htm');
    if (cached.existsSync() && !refresh) {
      pageByLetter[letter] = cached.readAsStringSync();
      continue;
    }
    final String body = await _fetchBody(
      Uri.parse('https://www.newadvent.org/cathen/$letter-ce.htm'),
      disallows,
      pacingClock,
    );
    cached.writeAsStringSync(body);
    pageByLetter[letter] = body;
  }

  final List<CeEntry> entries = <CeEntry>[];
  for (final String letter in _letters) {
    final List<CeEntry> parsed = parseCeIndex(pageByLetter[letter]!);
    stdout.writeln('letter $letter: ${parsed.length} articles');
    entries.addAll(parsed);
  }
  stdout.writeln('total article lines parsed: ${entries.length}');

  final Selection selection = buildSelection(saints: saints, entries: entries);

  _writeJson('$groundingDir/selection.json', toSelectionJson(selection));
  _writeJson('$groundingDir/selection_review.json', toReviewJson(selection));
  _writeJson('$groundingDir/manual_review.json', toManualReviewJson(selection));

  stdout.writeln('unique articles: ${entryCount(entries)}');
  stdout.writeln('counts: ${selection.counts}');
  stdout.writeln('collisions quarantined: ${selection.collisions.length}');
  stdout.writeln('conflicted quarantined: ${selection.conflicted.length}');
  stdout.writeln('fuzzy quarantined: ${selection.fuzzy.length}');
  final Map<String, int> dropReasons = <String, int>{};
  for (final SelectionDrop drop in selection.drops) {
    dropReasons[drop.reason] = (dropReasons[drop.reason] ?? 0) + 1;
  }
  stdout.writeln('drop reasons: $dropReasons');
  stdout.writeln('wrote: $groundingDir/selection.json');
  stdout.writeln('wrote: $groundingDir/selection_review.json');
  stdout.writeln('wrote: $groundingDir/manual_review.json');
  return selection;
}

/// Counts unique article codes among [entries].
int entryCount(List<CeEntry> entries) {
  return entries.map((CeEntry e) => e.code).toSet().length;
}

Future<void> main(List<String> args) async {
  try {
    await run(refresh: args.contains('--refresh'));
  } on SelectCeMatchesException catch (error) {
    stderr.writeln('select_ce_matches: $error');
    exitCode = 1;
  }
}
