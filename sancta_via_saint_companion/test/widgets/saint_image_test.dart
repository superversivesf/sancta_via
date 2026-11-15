// SaintImage widget tests (Task 11).
//
// Review Focus #4 pinned at the widget layer: a saint with a bundled
// thumbnail renders `Image.asset(..., package: 'saint_data')` and no widget
// anywhere in the tree ever uses the network; a saint without a thumbnail
// (or with a thumb file missing from the bundle — the Task 6 carry-forward,
// e.g. casimir/isaac-the-syrian/moses-the-black/perpetuus) renders the gray
// person-icon placeholder instead.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saint_companion/widgets/saint_image.dart';
import 'package:saint_data/saint_data.dart';

const Key _placeholderKey = Key('saint_image_placeholder');

Saint _saint({String? thumbAsset}) {
  return Saint(
    slug: 'sample-saint',
    name: 'St. Sample',
    feastDay: '06-13',
    bio: 'A sample saint biography long enough for validation.',
    thumbAsset: thumbAsset,
  );
}

Finder _networkImageFinder() {
  return find.byWidgetPredicate(
    (Widget widget) => widget is Image && widget.image is NetworkImage,
  );
}

void main() {
  testWidgets(
    'renders the bundled asset thumb for a saint with a thumbAsset and never uses the network',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SaintImage(
              saint: _saint(thumbAsset: 'assets/thumbs/sample-saint.jpg'),
              width: 48,
              height: 48,
            ),
          ),
        ),
      );

      final Image image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<AssetImage>());
      final AssetImage assetImage = image.image as AssetImage;
      expect(assetImage.assetName, 'assets/thumbs/sample-saint.jpg');
      expect(assetImage.package, 'saint_data');
      expect(image.fit, BoxFit.cover);
      expect(image.width, 48);
      expect(image.height, 48);

      // Review Focus #4: the network is never used for saint imagery.
      expect(_networkImageFinder(), findsNothing);
    },
  );

  testWidgets(
    'renders the gray person-icon placeholder for a saint without a thumbAsset',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SaintImage(saint: _saint(), width: 56, height: 56),
          ),
        ),
      );

      expect(find.byKey(_placeholderKey), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(_networkImageFinder(), findsNothing);
    },
  );

  testWidgets(
    'falls back to the placeholder when the declared thumb asset file is missing',
    (WidgetTester tester) async {
      // Task 6 carry-forward: some saints declare a thumbAsset whose file is
      // not in the bundle; the asset load error must surface the same gray
      // person-icon placeholder instead of crashing or showing a broken
      // image frame.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SaintImage(
              saint: _saint(thumbAsset: 'assets/thumbs/definitely-missing.jpg'),
              width: 56,
              height: 56,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(_placeholderKey), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(_networkImageFinder(), findsNothing);
    },
  );

  testWidgets(
    'a cover-cropped thumb anchors to the top so portrait faces survive',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SaintImage(
              saint: _saint(thumbAsset: 'assets/thumbs/sample-saint.jpg'),
              width: 80,
              height: 80,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Image image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.cover);
      expect(image.alignment, Alignment.topCenter,
          reason: 'center-crop of tall portraits cuts the head off — the '
              'crop must anchor to the top of the frame');
    },
  );
}
