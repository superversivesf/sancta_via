/// Structure validation for rebuilt Bible data.
///
/// Validates submitted verse data against the pinned expected structure
/// manifest (`tools/build_bibles/expected_structure.json`, produced by the
/// rebuild pipeline). The manifest pins, per translation id:
/// - `order`: the canonical 73-book sequence (Catholic canon);
/// - `chapters`: per book a map of decimal-STRING chapter keys -> verse count;
/// - `referenceVerses`: pins of `{book, chapter, verse, startsWith}`.
///
/// Comparison notes:
/// - Manifest chapter keys are decimal strings ("1", "18") per the Task 2
///   pin; they are parsed with [int.tryParse] and compared as ints against
///   the int chapter keys of the submitted data. The pin guarantees plain
///   decimal strings in 1-based sequence (never `''` or `'0'`), so parsing
///   is well-defined.
/// - The book SET must match `order` exactly; `order` itself is pinned and
///   is not re-derived or sequence-checked here.

/// Validates the structure and content of one or more rebuilt Bible
/// translations against a parsed `expected_structure.json` manifest.
///
/// Translations maps translation id -> book name (manifest db name) ->
/// chapter number -> verse number -> verse text.
///
/// Returns grep-able error strings; each starts with the translation id and
/// names the book (and chapter/verse where applicable) plus the rule, e.g.
/// `engwebc Psalms 118: contiguous numbering gap at verse 7`. An empty list
/// means the submitted data matches the manifest. All violations are
/// collected: validation never aborts early on the first error.
List<String> validateBibleStructure({
  required Map<String, Map<String, Map<int, Map<int, String>>>> translations,
  required Map<String, dynamic> expectedStructure,
}) {
  final List<String> errors = <String>[];
  final Object? expectedTranslationsObj = expectedStructure['translations'];
  if (expectedTranslationsObj is! Map<String, dynamic>) {
    errors.add('expected structure: malformed translations entry');
    return errors;
  }
  final Map<String, dynamic> expectedTranslations = expectedTranslationsObj;

  for (final String translationId in translations.keys) {
    if (!expectedTranslations.containsKey(translationId)) {
      errors.add(
        '$translationId: unexpected translation (not in expected structure)',
      );
    }
  }

  for (final MapEntry<String, dynamic> entry in expectedTranslations.entries) {
    final String translationId = entry.key;
    final Object? expectedObj = entry.value;
    if (expectedObj is! Map<String, dynamic>) {
      errors.add('$translationId: malformed expected translation entry');
      continue;
    }
    final Map<String, dynamic> expected = expectedObj;
    final Map<String, Map<int, Map<int, String>>>? dataBooks =
        translations[translationId];
    if (dataBooks == null) {
      errors.add('$translationId: translation missing from submitted data');
      continue;
    }
    errors.addAll(
      _validateTranslation(
        translationId: translationId,
        dataBooks: dataBooks,
        expected: expected,
      ),
    );
  }
  return errors;
}

/// Validates a single translation against its manifest entry.
List<String> _validateTranslation({
  required String translationId,
  required Map<String, Map<int, Map<int, String>>> dataBooks,
  required Map<String, dynamic> expected,
}) {
  final List<String> errors = <String>[];

  final Object? orderObj = expected['order'];
  if (orderObj is! List<dynamic>) {
    errors.add('$translationId: malformed order entry');
    return errors;
  }
  final List<String> order = orderObj.whereType<String>().toList();
  if (order.length != orderObj.length) {
    errors.add('$translationId: malformed order entry (non-string book name)');
  }

  final Object? chaptersObj = expected['chapters'];
  if (chaptersObj is! Map<String, dynamic>) {
    errors.add('$translationId: malformed chapters entry');
    return errors;
  }
  final Map<String, Map<String, int>> manifestChapters =
      <String, Map<String, int>>{};
  final List<String> malformedChapterBooks = <String>[];
  for (final MapEntry<String, dynamic> chapterEntry in chaptersObj.entries) {
    final Object? countsObj = chapterEntry.value;
    if (countsObj is! Map<String, dynamic>) {
      malformedChapterBooks.add(chapterEntry.key);
      continue;
    }
    final Map<String, int> counts = <String, int>{};
    bool malformed = false;
    for (final MapEntry<String, dynamic> count in countsObj.entries) {
      final Object? verseCount = count.value;
      if (verseCount is! int) {
        malformed = true;
        break;
      }
      counts[count.key] = verseCount;
    }
    if (malformed) {
      malformedChapterBooks.add(chapterEntry.key);
      continue;
    }
    manifestChapters[chapterEntry.key] = counts;
  }
  for (final String book in malformedChapterBooks) {
    errors.add('$translationId $book: malformed manifest chapters entry');
  }

  // Book-set equality with the manifest order.
  final Set<String> expectedBookSet = order.toSet();
  final Set<String> dataBookSet = dataBooks.keys.toSet();
  final Set<String> reportedMissing = <String>{};
  for (final String book in order) {
    if (!dataBookSet.contains(book) && !reportedMissing.contains(book)) {
      errors.add(
        '$translationId $book: missing book (required by manifest order)',
      );
      reportedMissing.add(book);
    }
  }
  final List<String> unexpectedBooks =
      dataBookSet
          .where((String book) => !expectedBookSet.contains(book))
          .toList()
        ..sort();
  for (final String book in unexpectedBooks) {
    errors.add('$translationId $book: unexpected book (not in manifest order)');
  }

  // Per-book chapter and verse checks for books present on both sides.
  final List<String> commonBooks =
      dataBookSet.intersection(expectedBookSet).toList()..sort();
  for (final String book in commonBooks) {
    final Map<int, Map<int, String>> dataChapters = dataBooks[book]!;
    if (!manifestChapters.containsKey(book)) {
      errors.add('$translationId $book: missing manifest chapter data');
      continue;
    }
    final Map<int, int> expectedChapters = <int, int>{};
    for (final MapEntry<String, int> count in manifestChapters[book]!.entries) {
      final int? chapterNo = int.tryParse(count.key);
      if (chapterNo == null) {
        errors.add(
          '$translationId $book: malformed manifest chapter key '
          '"${count.key}" (decimal string expected)',
        );
        continue;
      }
      expectedChapters[chapterNo] = count.value;
    }

    final Set<int> expectedChapterNos = expectedChapters.keys.toSet();
    final Set<int> dataChapterNos = dataChapters.keys.toSet();
    final List<int> missingChapters =
        expectedChapterNos
            .where((int chapter) => !dataChapterNos.contains(chapter))
            .toList()
          ..sort();
    final List<int> unexpectedChapters =
        dataChapterNos
            .where((int chapter) => !expectedChapterNos.contains(chapter))
            .toList()
          ..sort();
    for (final int chapter in missingChapters) {
      errors.add(
        '$translationId $book $chapter: missing chapter (required by manifest)',
      );
    }
    for (final int chapter in unexpectedChapters) {
      errors.add(
        '$translationId $book $chapter: unexpected chapter (not in manifest)',
      );
    }

    final List<int> commonChapters =
        dataChapterNos.intersection(expectedChapterNos).toList()..sort();
    for (final int chapter in commonChapters) {
      final int verseCount = expectedChapters[chapter]!;
      final Map<int, String> dataVerses = dataChapters[chapter]!;
      final Set<int> dataVerseNos = dataVerses.keys.toSet();

      // Verse keys must be exactly 1..verseCount, contiguous.
      for (int verse = 1; verse <= verseCount; verse++) {
        if (!dataVerseNos.contains(verse)) {
          errors.add(
            '$translationId $book $chapter: contiguous numbering gap at verse $verse',
          );
        }
      }
      final List<int> unexpectedVerses =
          dataVerseNos
              .where((int verse) => verse < 1 || verse > verseCount)
              .toList()
            ..sort();
      for (final int verse in unexpectedVerses) {
        errors.add(
          '$translationId $book $chapter: unexpected verse $verse '
          '(expected 1..$verseCount)',
        );
      }

      // Text content checks for every verse present in the data.
      final List<int> verseNos = dataVerseNos.toList()..sort();
      for (final int verse in verseNos) {
        final String text = dataVerses[verse]!;
        if (text.trim().isEmpty) {
          errors.add('$translationId $book $chapter:$verse: empty verse text');
        }
        if (text.contains('\\')) {
          errors.add(
            '$translationId $book $chapter:$verse: backslash in text (USFM marker leak)',
          );
        }
      }
    }
  }

  // Reference-verse pins.
  final Object? pinsObj = expected['referenceVerses'];
  if (pinsObj is! List<dynamic>) {
    errors.add('$translationId: malformed referenceVerses entry');
    return errors;
  }
  for (final Object? pinObj in pinsObj) {
    if (pinObj is! Map<String, dynamic>) {
      errors.add('$translationId: malformed reference verse pin');
      continue;
    }
    final Map<String, dynamic> pin = pinObj;
    final Object? bookObj = pin['book'];
    final Object? chapterObj = pin['chapter'];
    final Object? verseObj = pin['verse'];
    final Object? startsWithObj = pin['startsWith'];
    if (bookObj is! String ||
        chapterObj is! int ||
        verseObj is! int ||
        startsWithObj is! String) {
      errors.add('$translationId: malformed reference verse pin fields');
      continue;
    }
    if (!expectedBookSet.contains(bookObj)) {
      errors.add(
        '$translationId $bookObj: reference-verse book not in manifest order',
      );
      continue;
    }
    final String? text = dataBooks[bookObj]?[chapterObj]?[verseObj];
    if (text == null) {
      errors.add(
        '$translationId $bookObj $chapterObj:$verseObj: '
        'reference verse missing from data',
      );
      continue;
    }
    if (!text.startsWith(startsWithObj)) {
      errors.add(
        '$translationId $bookObj $chapterObj:$verseObj: '
        'reference-verse text mismatch (expected prefix "$startsWithObj")',
      );
    }
  }
  return errors;
}
