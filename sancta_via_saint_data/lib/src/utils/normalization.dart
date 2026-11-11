// Search-text normalization utilities for saint lookup.
//
// Both sides of search use these: the data-build side normalizes saint
// names into searchable tokens, and the query side normalizes user input
// the same way so the two match.

/// Characters kept by [normalizeSearchText]; everything else is stripped.
final RegExp _nonSearchPattern = RegExp('[^a-z0-9 ]');

/// Runs of two or more spaces, collapsed to a single space.
final RegExp _multiSpacePattern = RegExp(' {2,}');

/// UTF-16 code-unit fold table: accented Latin letters (post-lowercase)
/// mapped to their plain base letter or digraph.
///
/// Covers Latin-1, Latin Extended-A, and Latin Extended Additional
/// (Vietnamese) letters. Keys are the lowercase code units because input is
/// lowercased before folding; the corresponding uppercase code units are
/// unreachable. Only single-ASCII-letter decompositions plus the
/// non-decomposing special forms (æ œ ø đ ł ß thorn eth) are folded.
const Map<int, String> _diacriticFoldByUnit = <int, String>{
  223: 'ss',
  224: 'a',
  225: 'a',
  226: 'a',
  227: 'a',
  228: 'a',
  229: 'a',
  230: 'ae',
  231: 'c',
  232: 'e',
  233: 'e',
  234: 'e',
  235: 'e',
  236: 'i',
  237: 'i',
  238: 'i',
  239: 'i',
  240: 'd',
  241: 'n',
  242: 'o',
  243: 'o',
  244: 'o',
  245: 'o',
  246: 'o',
  248: 'o',
  249: 'u',
  250: 'u',
  251: 'u',
  252: 'u',
  253: 'y',
  254: 'th',
  255: 'y',
  257: 'a',
  259: 'a',
  261: 'a',
  263: 'c',
  265: 'c',
  267: 'c',
  269: 'c',
  271: 'd',
  273: 'd',
  275: 'e',
  277: 'e',
  279: 'e',
  281: 'e',
  283: 'e',
  285: 'g',
  287: 'g',
  289: 'g',
  291: 'g',
  293: 'h',
  297: 'i',
  299: 'i',
  301: 'i',
  303: 'i',
  309: 'j',
  311: 'k',
  314: 'l',
  316: 'l',
  318: 'l',
  322: 'l',
  324: 'n',
  326: 'n',
  328: 'n',
  333: 'o',
  335: 'o',
  337: 'o',
  339: 'oe',
  341: 'r',
  343: 'r',
  345: 'r',
  347: 's',
  349: 's',
  351: 's',
  353: 's',
  355: 't',
  357: 't',
  361: 'u',
  363: 'u',
  365: 'u',
  367: 'u',
  369: 'u',
  371: 'u',
  373: 'w',
  375: 'y',
  378: 'z',
  380: 'z',
  382: 'z',
  7681: 'a',
  7683: 'b',
  7685: 'b',
  7687: 'b',
  7689: 'c',
  7691: 'd',
  7693: 'd',
  7695: 'd',
  7697: 'd',
  7699: 'd',
  7701: 'e',
  7703: 'e',
  7705: 'e',
  7707: 'e',
  7709: 'e',
  7711: 'f',
  7713: 'g',
  7715: 'h',
  7717: 'h',
  7719: 'h',
  7721: 'h',
  7723: 'h',
  7725: 'i',
  7727: 'i',
  7729: 'k',
  7731: 'k',
  7733: 'k',
  7735: 'l',
  7737: 'l',
  7739: 'l',
  7741: 'l',
  7743: 'm',
  7745: 'm',
  7747: 'm',
  7749: 'n',
  7751: 'n',
  7753: 'n',
  7755: 'n',
  7757: 'o',
  7759: 'o',
  7761: 'o',
  7763: 'o',
  7765: 'p',
  7767: 'p',
  7769: 'r',
  7771: 'r',
  7773: 'r',
  7775: 'r',
  7777: 's',
  7779: 's',
  7781: 's',
  7783: 's',
  7785: 's',
  7787: 't',
  7789: 't',
  7791: 't',
  7793: 't',
  7795: 'u',
  7797: 'u',
  7799: 'u',
  7801: 'u',
  7803: 'u',
  7805: 'v',
  7807: 'v',
  7809: 'w',
  7811: 'w',
  7813: 'w',
  7815: 'w',
  7817: 'w',
  7819: 'x',
  7821: 'x',
  7823: 'y',
  7825: 'z',
  7827: 'z',
  7829: 'z',
  7830: 'h',
  7831: 't',
  7832: 'w',
  7833: 'y',
  7841: 'a',
  7843: 'a',
  7845: 'a',
  7847: 'a',
  7849: 'a',
  7851: 'a',
  7853: 'a',
  7855: 'a',
  7857: 'a',
  7859: 'a',
  7861: 'a',
  7863: 'a',
  7865: 'e',
  7867: 'e',
  7869: 'e',
  7871: 'e',
  7873: 'e',
  7875: 'e',
  7877: 'e',
  7879: 'e',
  7881: 'i',
  7883: 'i',
  7885: 'o',
  7887: 'o',
  7889: 'o',
  7891: 'o',
  7893: 'o',
  7895: 'o',
  7897: 'o',
  7899: 'o',
  7901: 'o',
  7903: 'o',
  7905: 'o',
  7907: 'o',
  7909: 'u',
  7911: 'u',
  7913: 'u',
  7915: 'u',
  7917: 'u',
  7919: 'u',
  7921: 'u',
  7923: 'y',
  7925: 'y',
  7927: 'y',
  7929: 'y',
};

/// Normalizes free text so names and queries compare equal.
///
/// Lowercases, folds diacritics (é→e, ö→o, ñ→n, …), strips every character
/// outside `a-z`, `0-9`, and space, then collapses runs of spaces and trims.
/// Stripped (not space-replaced) so e.g. `Émile's` folds to `emiles`.
String normalizeSearchText(String input) {
  final String lowered = input.toLowerCase();

  final StringBuffer folded = StringBuffer();
  for (final int unit in lowered.codeUnits) {
    final String? replacement = _diacriticFoldByUnit[unit];
    folded.write(replacement ?? String.fromCharCode(unit));
  }

  final String stripped = folded.toString().replaceAll(_nonSearchPattern, '');
  return stripped.replaceAll(_multiSpacePattern, ' ').trim();
}

/// Splits a user query into normalized search tokens.
///
/// Applies [normalizeSearchText], splits on single spaces, and drops empty
/// tokens. Returns an empty list for empty or whitespace-only queries.
List<String> tokenizeSearchQuery(String query) {
  final String normalized = normalizeSearchText(query);
  if (normalized.isEmpty) {
    return <String>[];
  }
  return normalized.split(' ');
}
