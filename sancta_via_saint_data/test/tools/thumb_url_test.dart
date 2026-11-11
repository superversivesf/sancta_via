// Unit tests for `wikimediaThumbUrl` in `tools/fetch_saint_images.dart`
// (Task 6 of the saint-companion plan).
//
// The function is the network tool's only tested surface: it is a pure
// top-level function so the thumbnail-generation logic can be pinned here,
// while the HTTP/process parts of the tool never run under `flutter test`
// (tests execute sandboxed, without network access). Pinned behavior: a
// URL carrying a Wikimedia `/thumb/…/<w>px-<name>` tail has `<w>` rewritten
// up to `max(width, 256)`; any URL without that shape comes back unchanged,
// whether it is foreign (`example.org`) or locally malformed.
import 'package:flutter_test/flutter_test.dart';

import '../../tools/fetch_saint_images.dart';

void main() {
  group('wikimediaThumbUrl', () {
    test('rewrites the tail width of a thumb URL to the default 256', () {
      expect(
        wikimediaThumbUrl(
          'https://upload.wikimedia.org/wikipedia/commons/thumb/'
          '8/88/Fresco.jpg/220px-Fresco.jpg',
        ),
        'https://upload.wikimedia.org/wikipedia/commons/thumb/'
        '8/88/Fresco.jpg/256px-Fresco.jpg',
      );
    });

    test('rewrites the tail width to a larger requested width', () {
      expect(
        wikimediaThumbUrl(
          'https://upload.wikimedia.org/wikipedia/commons/thumb/'
          '8/88/Fresco.jpg/220px-Fresco.jpg',
          width: 512,
        ),
        'https://upload.wikimedia.org/wikipedia/commons/thumb/'
        '8/88/Fresco.jpg/512px-Fresco.jpg',
      );
    });

    test('never requests below 256 (max(width, 256))', () {
      expect(
        wikimediaThumbUrl(
          'https://upload.wikimedia.org/wikipedia/commons/thumb/'
          '8/88/Fresco.jpg/220px-Fresco.jpg',
          width: 100,
        ),
        'https://upload.wikimedia.org/wikipedia/commons/thumb/'
        '8/88/Fresco.jpg/256px-Fresco.jpg',
      );
    });

    test('keeps the tail name (hyphens included) intact', () {
      expect(
        wikimediaThumbUrl(
          'https://upload.wikimedia.org/wikipedia/commons/thumb/'
          '3/3c/Saint_Aaron-detail.jpg/400px-Saint_Aaron-detail.jpg',
        ),
        'https://upload.wikimedia.org/wikipedia/commons/thumb/'
        '3/3c/Saint_Aaron-detail.jpg/256px-Saint_Aaron-detail.jpg',
      );
    });

    test('finds <w>px- in the last segment of multi-segment tails', () {
      // Rendered thumb of a TIFF original: the lossy-render marker is part
      // of one segment, before the `<w>px-` width token.
      expect(
        wikimediaThumbUrl(
          'https://upload.wikimedia.org/wikipedia/commons/thumb/'
          '9/9b/Foo.tiff/lossy-page1-220px-Foo.tiff.jpg',
        ),
        'https://upload.wikimedia.org/wikipedia/commons/thumb/'
        '9/9b/Foo.tiff/lossy-page1-256px-Foo.tiff.jpg',
      );
    });

    test('a URL without a thumb shape is returned unchanged', () {
      // Direct originals (e.g. `/commons/a/a0/name.jpg`) have no `<w>px-`
      // tail: they are downloaded as-is and downsized locally.
      expect(
        wikimediaThumbUrl(
          'https://upload.wikimedia.org/wikipedia/commons/a/a0/'
          '33_martyrs.jpg',
        ),
        'https://upload.wikimedia.org/wikipedia/commons/a/a0/'
        '33_martyrs.jpg',
      );
      expect(
        wikimediaThumbUrl('https://example.org/a.jpg'),
        'https://example.org/a.jpg',
      );
    });

    test('malformed input is returned unchanged', () {
      expect(wikimediaThumbUrl('not a url'), 'not a url');
      expect(wikimediaThumbUrl(''), '');
      expect(
        wikimediaThumbUrl(
          'https://upload.wikimedia.org/wikipedia/commons/thumb/8/88/'
          'Fresco.jpg',
        ),
        'https://upload.wikimedia.org/wikipedia/commons/thumb/8/88/'
        'Fresco.jpg',
      );
    });
  });
}
