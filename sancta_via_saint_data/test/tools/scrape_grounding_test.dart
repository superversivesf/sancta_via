// Unit tests for `tools/scrape_grounding.dart` (Task 2 of the
// saint-histories plan) — fixture-driven, NO network.
//
// Fixture: the REAL verified `cathen/06221a.htm` HTML (St. Francis of
// Assisi, the article pinned by the plan) saved verbatim from newadvent.org.
// The tests pin the clean-text contract:
//   * the article title is extracted,
//   * body text survives (real sentences, not just whitespace),
//   * CE site boilerplate is gone: the "help support the mission" promo,
//     the letter nav / breadcrumbs, the "See also" tail, the copyright and
//     citation blocks, ad divs, and any `../cathen` link artifacts,
//   * footnote markers (`[^N]`) stripped,
//   * paragraphs joined with blank lines.
// A second, synthetic mini-HTML covers boilerplate variants the Francis
// page itself does not exercise (a "See also" tail and `[^N]` markers).
// A final group pins the manifest.json row shape.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/scrape_grounding.dart';

final String _francisHtml = File(
  'test/fixtures/ce_article_francis.html',
).readAsStringSync();

void main() {
  group('scrapeGroundingArticle (real Francis fixture)', () {
    late GroundingArticle article;

    setUp(() {
      article = scrapeGroundingArticle(_francisHtml);
    });

    test('extracts the article title from the h1', () {
      expect(article.title, 'St. Francis of Assisi');
    });

    test('keeps real body text, first paragraph onward', () {
      expect(article.text, contains('Founder of the Franciscan Order'));
      expect(article.text, contains('born at Assisi in Umbria'));
      expect(article.text, contains('died there, 3 October, 1226'));
    });

    test('keeps the closing paragraphs, too', () {
      expect(
        article.text,
        contains('The writings of St. Francis have been published'),
      );
      expect(article.text, contains('Robinson, "The Writings of St. Francis'));
    });

    test('strips the help-support-the-mission promo', () {
      expect(article.text.contains('help support the mission'), isFalse);
      expect(article.text.contains('\$19.99'), isFalse);
      expect(article.text.contains('instant download'), isFalse);
    });

    test('strips the CE site nav header, search box, and breadcrumbs', () {
      expect(article.text.contains('Search:'), isFalse);
      expect(article.text.contains('Home > Catholic Encyclopedia'), isFalse);
      // The A-Z letter nav row.
      expect(RegExp(r'Z\s*&nbsp;\s*Z').hasMatch(article.text), isFalse);
      expect(article.text.contains('New Advent'), isFalse);
    });

    test('strips the About-this-page citations and approbation tail', () {
      expect(article.text.contains('APA citation'), isFalse);
      expect(article.text.contains('MLA citation'), isFalse);
      expect(article.text.contains('Ecclesiastical approbation'), isFalse);
      expect(article.text.contains('Contact information'), isFalse);
      expect(article.text.contains('Nihil Obstat'), isFalse);
    });

    test('strips the copyright tail', () {
      expect(article.text.contains('Copyright'), isFalse);
      expect(article.text.contains('New Advent LLC'), isFalse);
      expect(article.text.contains('CONTACT US'), isFalse);
      expect(article.text.contains('ADVERTISE'), isFalse);
    });

    test('leaves no link artifacts from the stripped anchors', () {
      expect(article.text.contains('../cathen'), isFalse);
      expect(article.text.contains('http'), isFalse);
    });

    test('joins paragraphs with blank lines and no triple breaks', () {
      // Every inter-paragraph break is exactly two newlines: a single
      // blank line, never a triple (or larger) gap.
      expect(article.text, contains('\n\n'));
      expect(article.text.contains('\n\n\n'), isFalse);
      // No indent or trailing whitespace survives on any line: paragraphs
      // are single-space-collapsed, and only the bare blank separator
      // lines are empty.
      for (final String line in article.text.split('\n')) {
        if (line.isNotEmpty) {
          expect(line, line.trim());
        }
      }
    });

    test('decodes entities in the body text', () {
      expect(article.text, contains('Poverello'));
      expect(article.text, contains('François'));
    });

    test('is a substantial clean text, far smaller than the raw HTML', () {
      expect(article.text.length, greaterThan(10000));
      expect(article.text.length, lessThan(75000));
    });
  });

  group('scrapeGroundingArticle (synthetic boilerplate variants)', () {
    // Boilerplate the Francis page does not exercise: a "See also" tail and
    // `[^N]` footnote markers.
    const String html =
        '<html><head><title>CATHOLIC ENCYCLOPEDIA: '
        'St. Böbl</title></head><body class="cathen">'
        '<div id="capitalcity"><a href="../cathen/a.htm">&nbsp;A&nbsp;</a>'
        '<a href="../cathen/b.htm">&nbsp;B&nbsp;</a></div>'
        '<div id="mi5"><span class="breadcrumbs"><a href="../">Home</a> '
        '&gt; <a href="../cathen">Catholic Encyclopedia</a> &gt; B</span>'
        '</div>'
        '<div id="springfield2"><h1>St. Böbl</h1>'
        '<p><em><a href="https://gumroad.com/l/na2"><strong>Please help '
        'support the mission of New Advent</strong> and get the full '
        'contents of this website as an instant download.</a></em></p>'
        '<p>Bishop of Böblingen[^1] in the fifth&#151;sixth century.[^2]'
        '</p><p>Second paragraph on his <a href="../cathen/07487a.htm">'
        'mission</a> work.</p>'
        '<div class="CMtag_300x250" style="height: 300px"></div>'
        '<p>See also: other saints of this name.</p>'
        '<p>See also, Catholic Encyclopedia, volume II.</p>'
        '<div class="pub"><h2>About this page</h2>'
        '<p><strong>APA citation.</strong> (1909). St. Böbl.</p>'
        '<p><strong>Ecclesiastical approbation.</strong> Nihil Obstat.</p>'
        '</div></div>'
        '<div id="ogdenville"><strong>Copyright &#169; 2026 by '
        '<a href="../utility/contactus.htm">New Advent LLC</a>.'
        '</strong></div></body></html>';

    late GroundingArticle article;

    setUp(() {
      article = scrapeGroundingArticle(html);
    });

    test('extracts the title, falling back to the page title', () {
      expect(article.title, 'St. Böbl');
    });

    test('keeps the body paragraphs in order', () {
      expect(article.text, contains('Bishop of Böblingen in the fifth'));
      expect(article.text, contains('Second paragraph on his mission work.'));
      final int first = article.text.indexOf('Bishop of');
      final int second = article.text.indexOf('Second paragraph');
      expect(first, lessThan(second));
    });

    test('strips `[^N]` footnote markers without eating adjacent text', () {
      expect(article.text.contains('['), isFalse);
      expect(article.text.contains('Böblingen in the fifth'), isTrue);
      expect(article.text.contains('century.'), isTrue);
    });

    test('strips See-also tails, nav, promo, citations, and copyright', () {
      expect(article.text.contains('See also'), isFalse);
      expect(article.text.contains('&nbsp;A&nbsp;'), isFalse);
      expect(article.text.contains('help support'), isFalse);
      expect(article.text.contains('APA citation'), isFalse);
      expect(article.text.contains('Nihil Obstat'), isFalse);
      expect(article.text.contains('New Advent LLC'), isFalse);
      expect(article.text.contains('../cathen'), isFalse);
    });

    test('joins surviving paragraphs with a single blank line', () {
      expect(article.text, contains('century.\n\nSecond paragraph'));
    });

    test('handles ad divs and scripts without leaking markup', () {
      expect(article.text.contains('<div'), isFalse);
      expect(article.text.contains('height: 300px'), isFalse);
    });
  });

  group('manifest row shape (pinned)', () {
    test('toManifestArticles emits exactly the pinned keys and values', () {
      final List<Map<String, dynamic>> rows = toManifestArticles(
        articles: <ScrapeResult>[
          ScrapeResult(
            slug: 'boebl',
            ceCode: '01026b',
            url: 'https://www.newadvent.org/cathen/01026b.htm',
            file: '01026b.txt',
            chars: 128,
            sha256: 'abc',
            fetchedAt: '2026-11-14T00:00:00.000Z',
          ),
        ],
      );
      expect(rows, hasLength(1));
      expect(rows.single.keys, <String>{
        'slug',
        'ceCode',
        'url',
        'file',
        'chars',
        'sha256',
        'fetchedAt',
      });
      expect(rows.single, <String, dynamic>{
        'slug': 'boebl',
        'ceCode': '01026b',
        'url': 'https://www.newadvent.org/cathen/01026b.htm',
        'file': '01026b.txt',
        'chars': 128,
        'sha256': 'abc',
        'fetchedAt': '2026-11-14T00:00:00.000Z',
      });
    });
  });
}
